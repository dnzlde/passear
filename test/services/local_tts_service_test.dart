import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/local_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_tts');
  const MethodChannel audioChannel = MethodChannel('com.ryanheise.audio_session');

  setUp(() {
    // Mock flutter_tts method calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setIosAudioCategory':
        case 'speak':
        case 'stop':
          return null;
        default:
          return null;
      }
    });

    // Mock audio_session method calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getConfiguration':
          return null;
        case 'setConfiguration':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
  });

  group('LocalTtsService', () {
    test('should initialize without throwing errors', () {
      expect(() => LocalTtsService(), returnsNormally);
    });

    test('should implement TtsService interface', () {
      final ttsService = LocalTtsService();
      expect(ttsService.speak('test'), isA<Future<void>>());
      expect(ttsService.stop(), isA<Future<void>>());
      expect(ttsService.dispose(), isA<Future<void>>());
    });

    test('should handle speak method call', () async {
      final ttsService = LocalTtsService();
      // This test verifies the method can be called without errors
      // Actual audio output cannot be tested in unit tests
      await expectLater(
        ttsService.speak('Test message'),
        completes,
      );
    });

    test('should handle stop method call', () async {
      final ttsService = LocalTtsService();
      await expectLater(
        ttsService.stop(),
        completes,
      );
    });

    test('should handle dispose method call', () async {
      final ttsService = LocalTtsService();
      await expectLater(
        ttsService.dispose(),
        completes,
      );
    });

    test('should handle multiple speak calls', () async {
      final ttsService = LocalTtsService();
      await expectLater(
        ttsService.speak('First message'),
        completes,
      );
      await expectLater(
        ttsService.speak('Second message'),
        completes,
      );
    });

    test('should handle speak after stop', () async {
      final ttsService = LocalTtsService();
      await ttsService.speak('Initial message');
      await ttsService.stop();
      await expectLater(
        ttsService.speak('Message after stop'),
        completes,
      );
    });
  });
}
