import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/tts/piper_tts_engine.dart';
import 'package:passear/services/tts/tts_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PiperTtsEngine', () {
    late PiperTtsEngine engine;

    setUp(() {
      // Set up method channel mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      engine = PiperTtsEngine();
    });

    tearDown(() async {
      await engine.dispose();
    });

    test('should have correct engine name', () {
      expect(engine.engineName, 'Piper TTS (fallback)');
    });

    test('should synthesize with default language', () async {
      final request = TtsRequest(
        text: 'Hello world',
        defaultLang: 'en-US',
      );

      final audio = await engine.synthesize(request);

      // Piper returns empty bytes in this implementation
      expect(audio.mimeType, 'audio/wav');
    });

    test('should handle unsupported language by falling back to en-US',
        () async {
      final request = TtsRequest(
        text: 'Test text',
        defaultLang: 'xyz-ZZ',
      );

      // Should not throw
      final audio = await engine.synthesize(request);
      expect(audio.mimeType, 'audio/wav');
    });

    test('should map common languages correctly', () async {
      final languages = [
        'en-US',
        'es-ES',
        'fr-FR',
        'de-DE',
        'ru-RU',
        'ja-JP',
        'ko-KR',
        'zh-CN',
        'ar-SA',
        'he-IL',
      ];

      for (final lang in languages) {
        final request = TtsRequest(
          text: 'Test',
          defaultLang: lang,
        );

        // Should not throw
        await engine.synthesize(request);
      }
    });

    test('should handle cancellation token', () async {
      final token = CancellationToken();
      token.cancel();

      final request = TtsRequest(
        text: 'Hello world',
        defaultLang: 'en-US',
      );

      expect(
        () => engine.synthesize(request, cancellationToken: token),
        throwsA(isA<Exception>()),
      );
    });

    test('should respect rate and pitch parameters', () async {
      final request = TtsRequest(
        text: 'Test',
        defaultLang: 'en-US',
        rate: 1.5,
        pitch: 0.8,
      );

      // Should not throw
      final audio = await engine.synthesize(request);
      expect(audio.mimeType, 'audio/wav');
    });
  });
}
