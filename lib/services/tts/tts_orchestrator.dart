import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../tts_service.dart';
import 'openai_tts_engine.dart';
import 'piper_tts_engine.dart';
import 'text_run_splitter.dart';
import 'tts_models.dart';

/// Orchestrator for multilingual TTS with OpenAI and Piper fallback
class TtsOrchestrator implements TtsService {
  final String openAiApiKey;
  final String ttsVoice;
  final bool forceOfflineMode; // For testing Piper without disabling internet

  // Dual AudioPlayer architecture for seamless transitions
  final AudioPlayer _primaryPlayer = AudioPlayer();
  final AudioPlayer _secondaryPlayer = AudioPlayer();
  late AudioPlayer
      _activePlayer; // Points to either _primaryPlayer or _secondaryPlayer

  final CancellationToken _cancellationToken = CancellationToken();
  final List<String> _tempFiles = [];
  final List<_QueueItem> _audioQueue = []; // Queue of audio items to play

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isSynthesizing = false;
  int _currentQueueIndex = 0;
  void Function()? _completionCallback;
  void Function(int current, int total)? _progressCallback;
  AudioSession? _audioSession;
  bool _audioSessionInitialized = false;

  // In-memory cache: text hash -> list of queue items (temporary files)
  final Map<String, List<_QueueItem>> _audioCache = {};

  // Chunk-level cache: (text, language) hash -> queue item
  // Deduplicates repeated chunks across different texts
  final Map<String, _QueueItem> _chunkCache = {};

  // Persistent cache fields
  Directory? _persistentCacheDir;
  bool _persistentCacheInitialized = false;
  final Map<String, List<String>> _persistentCache =
      {}; // text hash -> list of file paths
  final Map<String, DateTime> _cacheAccessTimes =
      {}; // text hash -> last access time
  static const int _maxCacheSizeBytes = 100 * 1024 * 1024; // 100MB
  static const String _cacheMetadataFile = 'cache_metadata.json';

  late final OpenAiTtsEngine _openAiEngine;
  late final PiperTtsEngine _piperEngine;

  TtsOrchestrator({
    required this.openAiApiKey,
    this.ttsVoice = 'alloy',
    this.forceOfflineMode = false,
  }) {
    _activePlayer = _primaryPlayer; // Initialize active player
    _openAiEngine = OpenAiTtsEngine(apiKey: openAiApiKey);
    _piperEngine = PiperTtsEngine();
    _setupAudioPlayers();
    _initPersistentCache();
  }

  void _setupAudioPlayers() {
    // Setup both players with completion listeners
    _primaryPlayer.playerStateStream.listen((state) {
      if (_activePlayer == _primaryPlayer &&
          state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _completionCallback?.call();
        _deactivateAudioSession();
      }
    });

    _secondaryPlayer.playerStateStream.listen((state) {
      if (_activePlayer == _secondaryPlayer &&
          state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _completionCallback?.call();
        _deactivateAudioSession();
      }
    });
  }

  /// Initialize persistent audio cache
  Future<void> _initPersistentCache() async {
    if (_persistentCacheInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _persistentCacheDir = Directory('${appDir.path}/tts_cache');

      // Create cache directory if it doesn't exist
      if (!await _persistentCacheDir!.exists()) {
        await _persistentCacheDir!.create(recursive: true);
        debugPrint('TtsOrchestrator: Created persistent cache directory');
      }

      // Load cache metadata
      await _loadCacheMetadata();

      // Clean old cache files if needed
      await _cleanOldCacheFiles();

      _persistentCacheInitialized = true;
      debugPrint('TtsOrchestrator: Persistent cache initialized');
    } catch (e) {
      debugPrint('TtsOrchestrator: Error initializing persistent cache: $e');
      // Continue without persistent cache
    }
  }

  /// Load cache metadata from disk
  Future<void> _loadCacheMetadata() async {
    if (_persistentCacheDir == null) return;

    try {
      final metadataFile =
          File('${_persistentCacheDir!.path}/$_cacheMetadataFile');
      if (await metadataFile.exists()) {
        final jsonStr = await metadataFile.readAsString();
        final Map<String, dynamic> metadata = json.decode(jsonStr);

        // Load cache mappings
        if (metadata.containsKey('cache')) {
          final cacheData = metadata['cache'] as Map<String, dynamic>;
          for (final entry in cacheData.entries) {
            _persistentCache[entry.key] = List<String>.from(entry.value);
          }
        }

        // Load access times
        if (metadata.containsKey('accessTimes')) {
          final accessData = metadata['accessTimes'] as Map<String, dynamic>;
          for (final entry in accessData.entries) {
            _cacheAccessTimes[entry.key] = DateTime.parse(entry.value);
          }
        }

        debugPrint(
            'TtsOrchestrator: Loaded ${_persistentCache.length} cached items');
      }
    } catch (e) {
      debugPrint('TtsOrchestrator: Error loading cache metadata: $e');
    }
  }

  /// Save cache metadata to disk
  Future<void> _saveCacheMetadata() async {
    if (_persistentCacheDir == null) return;

    try {
      final metadata = {
        'cache': _persistentCache,
        'accessTimes': _cacheAccessTimes
            .map((key, value) => MapEntry(key, value.toIso8601String())),
      };

      final metadataFile =
          File('${_persistentCacheDir!.path}/$_cacheMetadataFile');
      await metadataFile.writeAsString(json.encode(metadata));
    } catch (e) {
      debugPrint('TtsOrchestrator: Error saving cache metadata: $e');
    }
  }

  /// Calculate total cache size
  Future<int> _getCacheSize() async {
    if (_persistentCacheDir == null) return 0;

    int totalSize = 0;
    try {
      for (final filePaths in _persistentCache.values) {
        for (final path in filePaths) {
          final file = File(path);
          if (await file.exists()) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('TtsOrchestrator: Error calculating cache size: $e');
    }
    return totalSize;
  }

  /// Clean old cache files using LRU strategy
  Future<void> _cleanOldCacheFiles() async {
    if (_persistentCacheDir == null) return;

    try {
      final cacheSize = await _getCacheSize();
      if (cacheSize <= _maxCacheSizeBytes) return;

      debugPrint(
          'TtsOrchestrator: Cache size ($cacheSize bytes) exceeds limit, cleaning...');

      // Sort entries by access time (oldest first)
      final sortedEntries = _cacheAccessTimes.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      // Remove oldest entries until we're under the limit
      int removedSize = 0;
      for (final entry in sortedEntries) {
        if (cacheSize - removedSize <= _maxCacheSizeBytes * 0.8)
          break; // Keep 20% buffer

        final cacheKey = entry.key;
        if (_persistentCache.containsKey(cacheKey)) {
          // Delete files
          for (final filePath in _persistentCache[cacheKey]!) {
            try {
              final file = File(filePath);
              if (await file.exists()) {
                final fileSize = await file.length();
                await file.delete();
                removedSize += fileSize;
              }
            } catch (e) {
              debugPrint(
                  'TtsOrchestrator: Error deleting cache file $filePath: $e');
            }
          }

          // Remove from cache maps
          _persistentCache.remove(cacheKey);
          _cacheAccessTimes.remove(cacheKey);
        }
      }

      debugPrint('TtsOrchestrator: Cleaned $removedSize bytes from cache');
      await _saveCacheMetadata();
    } catch (e) {
      debugPrint('TtsOrchestrator: Error cleaning cache: $e');
    }
  }

  /// Load audio from persistent cache
  Future<List<_QueueItem>?> _loadFromPersistentCache(String cacheKey) async {
    if (_persistentCacheDir == null ||
        !_persistentCache.containsKey(cacheKey)) {
      return null;
    }

    try {
      final filePaths = _persistentCache[cacheKey]!;
      final queueItems = <_QueueItem>[];

      // Verify all files exist
      for (final path in filePaths) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('TtsOrchestrator: Cache file missing: $path');
          return null; // Cache is incomplete
        }
        queueItems.add(_QueueItem.file(path));
      }

      // Update access time
      _cacheAccessTimes[cacheKey] = DateTime.now();
      await _saveCacheMetadata();

      debugPrint(
          'TtsOrchestrator: Loaded ${queueItems.length} items from persistent cache');
      return queueItems;
    } catch (e) {
      debugPrint('TtsOrchestrator: Error loading from persistent cache: $e');
      return null;
    }
  }

  /// Save audio to persistent cache
  Future<void> _saveToPersistentCache(
      String cacheKey, List<String> tempFilePaths) async {
    if (_persistentCacheDir == null || tempFilePaths.isEmpty) return;

    try {
      final persistentPaths = <String>[];

      // Copy temporary files to persistent storage
      for (int i = 0; i < tempFilePaths.length; i++) {
        final tempFile = File(tempFilePaths[i]);
        if (await tempFile.exists()) {
          final extension = tempFile.path.endsWith('.mp3') ? 'mp3' : 'wav';
          final persistentPath =
              '${_persistentCacheDir!.path}/${cacheKey}_$i.$extension';
          final persistentFile = File(persistentPath);

          await tempFile.copy(persistentPath);
          persistentPaths.add(persistentPath);
        }
      }

      if (persistentPaths.isNotEmpty) {
        _persistentCache[cacheKey] = persistentPaths;
        _cacheAccessTimes[cacheKey] = DateTime.now();
        await _saveCacheMetadata();

        debugPrint(
            'TtsOrchestrator: Saved ${persistentPaths.length} files to persistent cache');

        // Clean old files if needed
        await _cleanOldCacheFiles();
      }
    } catch (e) {
      debugPrint('TtsOrchestrator: Error saving to persistent cache: $e');
    }
  }

  Future<void> _initAudioSession() async {
    if (_audioSessionInitialized) return;
    _audioSessionInitialized = true;

    try {
      _audioSession = await AudioSession.instance;
      await _audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers |
                  AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.assistanceNavigationGuidance,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
    } catch (e) {
      debugPrint('Failed to configure audio session: $e');
    }
  }

  Future<void> _deactivateAudioSession() async {
    if (_audioSession != null) {
      try {
        await _audioSession!.setActive(
          false,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        );
        debugPrint('Audio session deactivated successfully');
      } catch (e) {
        debugPrint('Failed to deactivate audio session: $e');
      }
    }
  }

  /// Get system locale as BCP-47 language code
  String _getSystemLanguage() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final languageCode = locale.languageCode;
      final countryCode = locale.countryCode;

      if (countryCode != null && countryCode.isNotEmpty) {
        return '$languageCode-$countryCode';
      }
      return languageCode;
    } catch (e) {
      debugPrint('Failed to get system locale: $e');
      return 'en-US';
    }
  }

  @override
  Future<void> speak(String text) async {
    // Don't cancel ongoing synthesis - let it finish while we prepare
    // Only cancel if we're actively synthesizing (not just playing)
    if (_isSynthesizing) {
      _cancellationToken.cancel();
    }

    // Reset cancellation token for new request
    _cancellationToken.reset();

    // Determine which player to use for preparation
    final AudioPlayer preparingPlayer =
        _activePlayer == _primaryPlayer ? _secondaryPlayer : _primaryPlayer;

    await _initAudioSession();
    await _initPersistentCache(); // Ensure persistent cache is ready

    final systemLang = _getSystemLanguage();
    debugPrint('TtsOrchestrator: System language: $systemLang');

    // Check caches (persistent first, then in-memory)
    final cacheKey = text.hashCode.toString();
    final List<_QueueItem> newAudioQueue = [];

    bool isCached = false;

    // Try persistent cache first
    final persistentItems = await _loadFromPersistentCache(cacheKey);
    if (persistentItems != null) {
      debugPrint('TtsOrchestrator: Using persistent cached audio');
      newAudioQueue.addAll(persistentItems);
      isCached = true;
    } else if (_audioCache.containsKey(cacheKey)) {
      // Try in-memory cache
      debugPrint('TtsOrchestrator: Using in-memory cached audio');
      newAudioQueue.addAll(_audioCache[cacheKey]!);
      isCached = true;
    }

    if (isCached) {
      // Cached audio - quick transition
      await _prepareAndSwapPlayer(preparingPlayer, newAudioQueue);
      return;
    }

    // Not cached - synthesize while current audio continues
    debugPrint('TtsOrchestrator: Synthesizing new audio on secondary player');
    _isSynthesizing = true;

    // Activate audio session if not active
    try {
      if (_audioSession != null && !_isPlaying) {
        await _audioSession!.setActive(true);
        debugPrint('Audio session activated for speaking');
      }
    } catch (e) {
      debugPrint('Failed to activate audio session: $e');
    }

    // Split text into runs by language
    final runs = TextRunSplitter.split(text, systemLang);
    debugPrint('TtsOrchestrator: Split into ${runs.length} language runs');

    if (runs.isEmpty) {
      debugPrint('TtsOrchestrator: No text to synthesize');
      _isSynthesizing = false;
      if (!_isPlaying) {
        _completionCallback?.call();
      }
      return;
    }

    try {
      // Synthesize all runs
      await _synthesizeAllRuns(runs, newAudioQueue);

      // Cache the synthesized audio (both in-memory and persistent)
      if (newAudioQueue.isNotEmpty) {
        // In-memory cache
        _audioCache[cacheKey] = List.from(newAudioQueue);
        debugPrint('TtsOrchestrator: Cached audio in memory');

        // Persistent cache - save file-based audio only
        final filePaths = newAudioQueue
            .where((item) => item.isFile)
            .map((item) => item.filePath!)
            .toList();

        if (filePaths.isNotEmpty) {
          await _saveToPersistentCache(cacheKey, filePaths);
        }
      }

      _isSynthesizing = false;

      // Prepare and swap to new audio
      if (newAudioQueue.isNotEmpty && !_cancellationToken.isCancelled) {
        await _prepareAndSwapPlayer(preparingPlayer, newAudioQueue);
      } else {
        debugPrint('TtsOrchestrator: No audio queue to play');
        if (!_isPlaying) {
          _completionCallback?.call();
          await _deactivateAudioSession();
        }
      }
    } catch (e) {
      debugPrint('TtsOrchestrator: Error during synthesis: $e');
      _isSynthesizing = false;
      if (!_isPlaying) {
        _completionCallback?.call();
        await _deactivateAudioSession();
      }
    }
  }

  /// Prepare new audio on a player and swap to it
  Future<void> _prepareAndSwapPlayer(
      AudioPlayer targetPlayer, List<_QueueItem> queue) async {
    // Activate audio session
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        debugPrint('Audio session activated');
      }
    } catch (e) {
      debugPrint('Failed to activate audio session: $e');
    }

    // Prepare the first audio item on the target player BEFORE stopping old player
    // This preloads the audio so it's ready to play immediately after swap
    if (queue.isNotEmpty) {
      try {
        final firstItem = queue[0];
        if (firstItem.isFile) {
          await targetPlayer.setFilePath(firstItem.filePath!);
          debugPrint(
              'TtsOrchestrator: Preloaded first audio file on new player');
        }
        // Note: Direct TTS (isDirect) doesn't need preloading
      } catch (e) {
        debugPrint('TtsOrchestrator: Error preloading audio on new player: $e');
      }
    }

    // NOW stop the old player - new player is already loaded and ready
    final oldPlayer = _activePlayer;
    try {
      await oldPlayer.stop();
      debugPrint('TtsOrchestrator: Stopped old player');
    } catch (e) {
      debugPrint('TtsOrchestrator: Error stopping old player: $e');
    }

    // Swap to new player and queue
    _activePlayer = targetPlayer;
    _audioQueue.clear();
    _audioQueue.addAll(queue);
    _currentQueueIndex = 0;
    _isPlaying = true;
    _isPaused = false;

    debugPrint('TtsOrchestrator: Swapped to new player, starting playback');

    // Start playing the new queue (first item already loaded, so this is fast)
    await _playQueue();
  }

  Future<void> _synthesizeAllRuns(
      List<TextRun> runs, List<_QueueItem> targetQueue) async {
    int synthesizedCount = 0;

    // Only report progress for OpenAI mode (file-based synthesis with delays)
    // For Piper mode (direct TTS), progress bar doesn't make sense
    final bool isOpenAiMode = openAiApiKey.isNotEmpty && !forceOfflineMode;

    // Report initial progress (0 of total) so UI can show progress bar immediately
    if (isOpenAiMode) {
      _progressCallback?.call(0, runs.length);
    }

    // For better performance, synthesize in parallel when using OpenAI (unless forced offline)
    if (isOpenAiMode) {
      // Synthesize up to 3 runs in parallel to avoid overwhelming the API
      final batchSize = 3;
      for (int i = 0; i < runs.length; i += batchSize) {
        if (_cancellationToken.isCancelled) break;

        final batch = runs.skip(i).take(batchSize).toList();
        final futures = batch.map((run) => _synthesizeRun(run)).toList();
        final results = await Future.wait(futures);

        // Add successful results to queue in order
        for (final result in results) {
          if (result != null && !_cancellationToken.isCancelled) {
            targetQueue.add(result);
            synthesizedCount++;
            if (isOpenAiMode) {
              _progressCallback?.call(synthesizedCount, runs.length);
            }
          }
        }
      }
    } else {
      // For Piper fallback, synthesize sequentially
      // No progress reporting for Piper since synthesis is instant
      for (final run in runs) {
        if (_cancellationToken.isCancelled) break;
        final result = await _synthesizeRun(run);
        if (result != null) {
          targetQueue.add(result);
          synthesizedCount++;
          // No progress callback for Piper mode
        }
      }
    }
  }

  Future<_QueueItem?> _synthesizeRun(TextRun run) async {
    // Create cache key from text and language
    final chunkCacheKey = '${run.text}|${run.language}';

    // Check chunk cache first
    if (_chunkCache.containsKey(chunkCacheKey)) {
      debugPrint(
          'TtsOrchestrator: Reusing cached chunk for "${run.text}" in ${run.language}');
      return _chunkCache[chunkCacheKey];
    }

    debugPrint(
        'TtsOrchestrator: Synthesizing run in ${run.language}: "${run.text}"');

    final request = TtsRequest(
      text: run.text,
      defaultLang: run.language,
      voice: ttsVoice,
    );

    TtsAudio? audio;
    String engineUsed = '';

    // Try OpenAI first (unless forced offline mode)
    if (openAiApiKey.isNotEmpty && !forceOfflineMode) {
      try {
        audio = await _openAiEngine.synthesize(
          request,
          cancellationToken: _cancellationToken,
        );
        engineUsed = _openAiEngine.engineName;
      } catch (e) {
        debugPrint('OpenAI TTS failed, falling back to Piper: $e');
      }
    }

    // Fallback to Piper if OpenAI failed or not configured
    if (audio == null) {
      try {
        audio = await _piperEngine.synthesize(
          request,
          cancellationToken: _cancellationToken,
        );
        engineUsed = _piperEngine.engineName;
      } catch (e) {
        debugPrint('Piper TTS failed: $e');
        return null;
      }
    }

    debugPrint('TtsOrchestrator: Using engine: $engineUsed');

    _QueueItem? queueItem;

    // Save audio to file if we have bytes
    if (audio.bytes.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = audio.mimeType == 'audio/mpeg' ? 'mp3' : 'wav';
        final tempFile = File('${tempDir.path}/tts_$timestamp.$extension');

        await tempFile.writeAsBytes(audio.bytes);
        _tempFiles.add(tempFile.path);

        debugPrint(
            'TtsOrchestrator: Saved audio file: ${tempFile.path} (${audio.bytes.length} bytes)');

        queueItem = _QueueItem.file(tempFile.path);
      } catch (e) {
        debugPrint('TtsOrchestrator: Error saving audio: $e');
        return null;
      }
    } else {
      // For Piper fallback with empty bytes, queue for direct playback
      debugPrint(
          'TtsOrchestrator: No audio bytes, queuing for flutter_tts playback');
      queueItem = _QueueItem.direct(run.text, run.language);
    }

    // Cache this chunk for future reuse
    if (queueItem != null) {
      _chunkCache[chunkCacheKey] = queueItem;
      debugPrint(
          'TtsOrchestrator: Cached chunk for "${run.text}" in ${run.language}');
    }

    return queueItem;
  }

  Future<void> _playQueue() async {
    while (_currentQueueIndex < _audioQueue.length &&
        !_cancellationToken.isCancelled) {
      if (_isPaused) {
        // Wait while paused
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final queueItem = _audioQueue[_currentQueueIndex];
      debugPrint(
          'TtsOrchestrator: Playing item ${_currentQueueIndex + 1}/${_audioQueue.length}');

      try {
        if (queueItem.isFile) {
          // Play audio file
          await _activePlayer.setFilePath(queueItem.filePath!);

          // Update state before starting playback
          _isPlaying = true;

          await _activePlayer.play();

          // Wait for playback to complete or cancellation
          await _activePlayer.playerStateStream.firstWhere(
            (state) =>
                state.processingState == ProcessingState.completed ||
                _cancellationToken.isCancelled ||
                _isPaused,
          );

          // Reduce pause between chunks for smoother transitions
          // Small delay to allow audio system to prepare next chunk
          if (_currentQueueIndex < _audioQueue.length - 1 &&
              !_cancellationToken.isCancelled &&
              !_isPaused) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } else if (queueItem.isDirect) {
          // Use flutter_tts directly
          debugPrint(
              'TtsOrchestrator: Using flutter_tts for: "${queueItem.text}"');

          // Update state before starting playback
          _isPlaying = true;

          // Set the language for this text
          await _piperEngine.setLanguageForDirect(queueItem.language!);

          // Speak and wait for completion using a simple flag
          bool isCompleted = false;

          // Set completion handler before speaking
          _piperEngine.tts.setCompletionHandler(() {
            if (!isCompleted) {
              isCompleted = true;
              debugPrint('TtsOrchestrator: Piper TTS completed for item');
            }
          });

          await _piperEngine.tts.speak(queueItem.text!);

          // Wait for completion or cancellation with timeout
          final timeout = Duration(seconds: queueItem.text!.length ~/ 10 + 10);
          final startTime = DateTime.now();
          while (!isCompleted &&
              !_cancellationToken.isCancelled &&
              !_isPaused &&
              DateTime.now().difference(startTime) < timeout) {
            await Future.delayed(const Duration(milliseconds: 100));
          }

          // If timed out, log it
          if (!isCompleted && !_cancellationToken.isCancelled && !_isPaused) {
            debugPrint('TtsOrchestrator: Piper TTS timed out');
          }

          // Minimal pause between Piper chunks for smoother transitions
          if (_currentQueueIndex < _audioQueue.length - 1 &&
              !_cancellationToken.isCancelled &&
              !_isPaused) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }

        if (!_isPaused && !_cancellationToken.isCancelled) {
          _currentQueueIndex++;
        }
      } catch (e) {
        debugPrint('TtsOrchestrator: Error playing item: $e');
        _currentQueueIndex++;
      }
    }

    // All done
    if (_currentQueueIndex >= _audioQueue.length &&
        !_cancellationToken.isCancelled &&
        !_isPaused) {
      _isPlaying = false;
      _completionCallback?.call();
      await _deactivateAudioSession();
      await _cleanupTempFiles();
    }
  }

  @override
  Future<void> stop() async {
    _cancellationToken.cancel();
    _isPlaying = false;
    _isPaused = false;
    _isSynthesizing = false;
    _audioQueue.clear();
    _currentQueueIndex = 0;

    try {
      await _primaryPlayer.stop();
      await _secondaryPlayer.stop();
      await _piperEngine.tts.stop(); // Also stop Piper if it's playing
    } catch (e) {
      debugPrint('Error stopping audio players: $e');
    }

    await _deactivateAudioSession();
    await _cleanupTempFiles();
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying) return;

    _isPaused = true;
    _isPlaying = false;

    try {
      await _activePlayer.pause();
      await _piperEngine.tts.stop(); // Stop Piper playback (no pause support)
    } catch (e) {
      debugPrint('Error pausing audio player: $e');
    }

    await _deactivateAudioSession();
  }

  /// Resume playback from where it was paused
  Future<void> resume() async {
    if (!_isPaused) return;

    _isPaused = false;
    _isPlaying = true;

    // Reactivate audio session
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        debugPrint('Audio session activated for resume');
      }
    } catch (e) {
      debugPrint('Failed to activate audio session: $e');
    }

    try {
      await _activePlayer.play();

      // Continue playing the queue if not yet finished synthesizing
      if (!_isSynthesizing && _currentQueueIndex < _audioQueue.length) {
        await _playQueue();
      }
    } catch (e) {
      debugPrint('Error resuming audio player: $e');
    }
  }

  Future<void> _cleanupTempFiles() async {
    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp file $path: $e');
      }
    }
    _tempFiles.clear();
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  bool get isSynthesizing => _isSynthesizing;

  @override
  void setCompletionCallback(void Function() callback) {
    _completionCallback = callback;
  }

  @override
  void setProgressCallback(void Function(int current, int total) callback) {
    _progressCallback = callback;
  }

  @override
  Future<void> dispose() async {
    _cancellationToken.cancel();
    await stop();
    await _primaryPlayer.dispose();
    await _secondaryPlayer.dispose();
    await _piperEngine.dispose();
    await _cleanupTempFiles();

    // Save persistent cache metadata before shutdown
    await _saveCacheMetadata();
  }
}

/// Internal class for queue items
class _QueueItem {
  final String? filePath; // Path to audio file (null for direct TTS)
  final String? text; // Text for direct TTS (null for file)
  final String? language; // Language for direct TTS

  _QueueItem.file(this.filePath)
      : text = null,
        language = null;

  _QueueItem.direct(this.text, this.language) : filePath = null;

  bool get isFile => filePath != null;
  bool get isDirect => text != null;
}
