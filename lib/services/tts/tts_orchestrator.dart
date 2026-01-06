import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
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
  final AudioPlayer _audioPlayer = AudioPlayer();
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

  // Audio cache: text hash -> list of queue items
  final Map<String, List<_QueueItem>> _audioCache = {};

  late final OpenAiTtsEngine _openAiEngine;
  late final PiperTtsEngine _piperEngine;

  TtsOrchestrator({
    required this.openAiApiKey,
    this.ttsVoice = 'alloy',
    this.forceOfflineMode = false,
  }) {
    _openAiEngine = OpenAiTtsEngine(apiKey: openAiApiKey);
    _piperEngine = PiperTtsEngine();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _completionCallback?.call();
        _deactivateAudioSession();
      }
    });
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
    // Cancel any ongoing synthesis
    _cancellationToken.cancel();
    await stop();

    // Reset cancellation token for new request
    _cancellationToken.reset();
    
    // Clear audio queue
    _audioQueue.clear();
    _currentQueueIndex = 0;

    await _initAudioSession();

    // Activate audio session
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
        debugPrint('Audio session activated for speaking');
      }
    } catch (e) {
      debugPrint('Failed to activate audio session: $e');
    }

    _isPlaying = true;
    _isPaused = false;

    final systemLang = _getSystemLanguage();
    debugPrint('TtsOrchestrator: System language: $systemLang');

    // Check cache first
    final cacheKey = text.hashCode.toString();
    if (_audioCache.containsKey(cacheKey)) {
      debugPrint('TtsOrchestrator: Using cached audio for this text');
      _audioQueue.addAll(_audioCache[cacheKey]!);
      
      // For file-based playback (OpenAI), synthesis is already done
      // For direct TTS (Piper), keep synthesis flag until playback completes
      final hasDirectTts = _audioQueue.any((item) => item.isDirect);
      if (!hasDirectTts) {
        _isSynthesizing = false;
      }
      
      // Start playing the queue immediately
      if (_audioQueue.isNotEmpty && !_cancellationToken.isCancelled) {
        await _playQueue();
        // For direct TTS, mark synthesis complete after playback
        if (hasDirectTts) {
          _isSynthesizing = false;
        }
      } else {
        _isSynthesizing = false;
      }
      return;
    }

    _isSynthesizing = true;

    // Split text into runs by language
    final runs = TextRunSplitter.split(text, systemLang);
    debugPrint('TtsOrchestrator: Split into ${runs.length} language runs');

    if (runs.isEmpty) {
      debugPrint('TtsOrchestrator: No text to synthesize');
      _isPlaying = false;
      _isSynthesizing = false;
      _completionCallback?.call();
      return;
    }

    try {
      // Synthesize all runs in parallel (for OpenAI) or sequentially (for Piper)
      await _synthesizeAllRuns(runs);
      
      // Cache the synthesized audio
      if (_audioQueue.isNotEmpty) {
        _audioCache[cacheKey] = List.from(_audioQueue);
        debugPrint('TtsOrchestrator: Cached audio for future playback');
      }
      
      // For file-based playback (OpenAI), mark synthesis complete before playback
      // For direct TTS (Piper), keep synthesis flag until playback completes
      final hasDirectTts = _audioQueue.any((item) => item.isDirect);
      if (!hasDirectTts) {
        _isSynthesizing = false;
      }
      
      // Start playing the queue
      if (_audioQueue.isNotEmpty && !_cancellationToken.isCancelled) {
        await _playQueue();
        // For direct TTS, mark synthesis complete after playback
        if (hasDirectTts) {
          _isSynthesizing = false;
        }
      } else {
        // No audio to play - complete immediately
        debugPrint('TtsOrchestrator: No audio queue to play');
        _isPlaying = false;
        _isSynthesizing = false;
        _completionCallback?.call();
        await _deactivateAudioSession();
      }
    } catch (e) {
      debugPrint('TtsOrchestrator: Error during synthesis: $e');
      _isPlaying = false;
      _isSynthesizing = false;
      _completionCallback?.call();
      await _deactivateAudioSession();
    }
  }

  Future<void> _synthesizeAllRuns(List<TextRun> runs) async {
    int synthesizedCount = 0;
    
    // Report initial progress (0 of total) so UI can show progress bar immediately
    _progressCallback?.call(0, runs.length);
    
    // For better performance, synthesize in parallel when using OpenAI (unless forced offline)
    if (openAiApiKey.isNotEmpty && !forceOfflineMode) {
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
            _audioQueue.add(result);
            synthesizedCount++;
            _progressCallback?.call(synthesizedCount, runs.length);
          }
        }
      }
    } else {
      // For Piper fallback, synthesize sequentially
      for (final run in runs) {
        if (_cancellationToken.isCancelled) break;
        final result = await _synthesizeRun(run);
        if (result != null) {
          _audioQueue.add(result);
          synthesizedCount++;
          _progressCallback?.call(synthesizedCount, runs.length);
        }
      }
    }
  }

  Future<_QueueItem?> _synthesizeRun(TextRun run) async {
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
        
        return _QueueItem.file(tempFile.path);
      } catch (e) {
        debugPrint('TtsOrchestrator: Error saving audio: $e');
        return null;
      }
    } else {
      // For Piper fallback with empty bytes, queue for direct playback
      debugPrint(
          'TtsOrchestrator: No audio bytes, queuing for flutter_tts playback');
      return _QueueItem.direct(run.text, run.language);
    }
  }

  Future<void> _playQueue() async {
    while (_currentQueueIndex < _audioQueue.length && !_cancellationToken.isCancelled) {
      if (_isPaused) {
        // Wait while paused
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final queueItem = _audioQueue[_currentQueueIndex];
      debugPrint('TtsOrchestrator: Playing item ${_currentQueueIndex + 1}/${_audioQueue.length}');

      try {
        if (queueItem.isFile) {
          // Play audio file
          await _audioPlayer.setFilePath(queueItem.filePath!);
          
          // Update state before starting playback
          _isPlaying = true;
          
          await _audioPlayer.play();

          // Wait for playback to complete or cancellation
          await _audioPlayer.playerStateStream.firstWhere(
            (state) =>
                state.processingState == ProcessingState.completed ||
                _cancellationToken.isCancelled ||
                _isPaused,
          );
        } else if (queueItem.isDirect) {
          // Use flutter_tts directly
          debugPrint('TtsOrchestrator: Using flutter_tts for: "${queueItem.text}"');
          
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
    if (_currentQueueIndex >= _audioQueue.length && !_cancellationToken.isCancelled && !_isPaused) {
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
      await _audioPlayer.stop();
      await _piperEngine.tts.stop(); // Also stop Piper if it's playing
    } catch (e) {
      debugPrint('Error stopping audio player: $e');
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
      await _audioPlayer.pause();
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
      await _audioPlayer.play();
      
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
    await _audioPlayer.dispose();
    await _piperEngine.dispose();
    await _cleanupTempFiles();
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
