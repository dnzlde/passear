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
  AudioSession? _audioSession;

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
      
      // Deactivate audio session when audio completes
      _deactivateAudioSession();
    });
    
    // Set up error handler
    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _completionCallback?.call();
      
      // Deactivate audio session on error
      _deactivateAudioSession();
    });

    try {
      // Use audio_session for both iOS and Android for consistent behavior
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

      // Activate the audio session
      await _audioSession!.setActive(true);
    } catch (e) {
      // Silently handle audio session configuration errors
      // This prevents the app from failing if audio configuration is not supported
      debugPrint('Failed to configure audio session: $e');
    }
  }

  /// Helper method to deactivate audio session and release audio focus
  void _deactivateAudioSession() {
    if (_audioSession != null) {
      _audioSession!.setActive(false).catchError((e) {
        debugPrint('Failed to deactivate audio session: $e');
      });
    }
  }

  @override
  Future<void> speak(String text) async {
    await _initAudioSession();
    
    // Reactivate audio session if it was deactivated (e.g., after pause)
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
      }
    } catch (e) {
      debugPrint('Failed to reactivate audio session: $e');
    }
    
    _isPlaying = true;
    _isPaused = false;
    return _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _isPaused = false;
    await _tts.stop();
    
    // Deactivate audio session to release audio focus
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }
    } catch (e) {
      debugPrint('Failed to deactivate audio session on stop: $e');
    }
  }

  @override
  Future<void> pause() async {
    _isPaused = true;
    _isPlaying = false;
    await _tts.pause();
    
    // Deactivate audio session to release audio focus and restore other audio to normal volume
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }
    } catch (e) {
      debugPrint('Failed to deactivate audio session on pause: $e');
    }
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> dispose() async {
    _isPlaying = false;
    _isPaused = false;
    await _tts.stop();
    
    // Deactivate audio session on dispose
    try {
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }
    } catch (e) {
      debugPrint('Failed to deactivate audio session on dispose: $e');
    }
  }
}
