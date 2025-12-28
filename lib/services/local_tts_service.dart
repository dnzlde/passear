import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';
import 'tts_service.dart';

class LocalTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _audioSessionInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  void Function()? _completionCallback;

  LocalTtsService() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
  }

  @override
  void setCompletionCallback(void Function() callback) {
    _completionCallback = callback;
  }

  Future<void> _initAudioSession() async {
    if (_audioSessionInitialized) return;
    _audioSessionInitialized = true;

    // Set up completion handler
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _completionCallback?.call();
    });
    
    // Set up error handler
    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _completionCallback?.call();
    });

    try {
      // Use audio_session for both iOS and Android for consistent behavior
      final session = await AudioSession.instance;
      await session.configure(
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

      // Activate the audio session
      await session.setActive(true);
    } catch (e) {
      // Silently handle audio session configuration errors
      // This prevents the app from failing if audio configuration is not supported
      debugPrint('Failed to configure audio session: $e');
    }
  }

  @override
  Future<void> speak(String text) async {
    await _initAudioSession();
    _isPlaying = true;
    _isPaused = false;
    return _tts.speak(text);
  }

  @override
  Future<void> stop() {
    _isPlaying = false;
    _isPaused = false;
    return _tts.stop();
  }

  @override
  Future<void> pause() {
    _isPaused = true;
    _isPlaying = false;
    return _tts.pause();
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() {
    _isPlaying = false;
    _isPaused = false;
    return _tts.stop();
  }
}
