import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

class LocalTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();

  LocalTtsService() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
  }

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}
