import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_session/audio_session.dart';
import 'tts_service.dart';

class LocalTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _audioSessionInitialized = false;

  LocalTtsService() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
  }

  Future<void> _initAudioSession() async {
    if (_audioSessionInitialized) return;
    _audioSessionInitialized = true;

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
    return _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}
