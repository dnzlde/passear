import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/local_tts_service.dart';

void main() {
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
