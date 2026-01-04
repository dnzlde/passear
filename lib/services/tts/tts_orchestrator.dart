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
  final List<String> _audioQueue = []; // Queue of synthesized audio file paths

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isSynthesizing = false;
  int _currentQueueIndex = 0;
  void Function()? _completionCallback;
  AudioSession? _audioSession;
  bool _audioSessionInitialized = false;

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
    _isSynthesizing = true;

    final systemLang = _getSystemLanguage();
    debugPrint('TtsOrchestrator: System language: $systemLang');

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
      _isSynthesizing = false;
      
      // Start playing the queue
      if (_audioQueue.isNotEmpty && !_cancellationToken.isCancelled) {
        await _playQueue();
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
        }
      }
    }
  }

  Future<String?> _synthesizeRun(TextRun run) async {
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
        
        return tempFile.path;
      } catch (e) {
        debugPrint('TtsOrchestrator: Error saving audio: $e');
        return null;
      }
    } else {
      // For Piper fallback with empty bytes, speak directly
      debugPrint(
          'TtsOrchestrator: No audio bytes, using flutter_tts for playback');
      await _piperEngine.speakDirect(run.text);
      return null; // Return null to indicate no file was created
    }
  }

  Future<void> _playQueue() async {
    while (_currentQueueIndex < _audioQueue.length && !_cancellationToken.isCancelled) {
      if (_isPaused) {
        // Wait while paused
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final audioPath = _audioQueue[_currentQueueIndex];
      debugPrint('TtsOrchestrator: Playing audio ${_currentQueueIndex + 1}/${_audioQueue.length}: $audioPath');

      try {
        await _audioPlayer.setFilePath(audioPath);
        await _audioPlayer.play();

        // Wait for playback to complete or cancellation
        await _audioPlayer.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              _cancellationToken.isCancelled ||
              _isPaused,
        );

        if (!_isPaused && !_cancellationToken.isCancelled) {
          _currentQueueIndex++;
        }
      } catch (e) {
        debugPrint('TtsOrchestrator: Error playing audio: $e');
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
  void setCompletionCallback(void Function() callback) {
    _completionCallback = callback;
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
