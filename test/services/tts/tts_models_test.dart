import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/tts/tts_models.dart';

void main() {
  group('TtsRequest', () {
    test('should create request with required fields', () {
      final request = TtsRequest(text: 'Hello world', defaultLang: 'en-US');

      expect(request.text, 'Hello world');
      expect(request.defaultLang, 'en-US');
      expect(request.rate, 1.0);
      expect(request.pitch, 1.0);
      expect(request.voice, 'alloy');
    });

    test('should create request with custom parameters', () {
      final request = TtsRequest(
        text: 'Test',
        defaultLang: 'fr-FR',
        rate: 1.5,
        pitch: 0.8,
        voice: 'nova',
      );

      expect(request.text, 'Test');
      expect(request.defaultLang, 'fr-FR');
      expect(request.rate, 1.5);
      expect(request.pitch, 0.8);
      expect(request.voice, 'nova');
    });
  });

  group('TtsAudio', () {
    test('should store audio bytes and mime type', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final audio = TtsAudio(bytes: bytes, mimeType: 'audio/mpeg');

      expect(audio.bytes, bytes);
      expect(audio.mimeType, 'audio/mpeg');
    });
  });

  group('CancellationToken', () {
    test('should start as not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, false);
    });

    test('should be cancelled after calling cancel', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('should reset to not cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, true);

      token.reset();
      expect(token.isCancelled, false);
    });
  });

  group('TextRun', () {
    test('should create text run', () {
      final run = TextRun(text: 'Hello', language: 'en-US');

      expect(run.text, 'Hello');
      expect(run.language, 'en-US');
    });

    test('should have string representation', () {
      final run = TextRun(text: 'Hello', language: 'en-US');

      expect(run.toString(), contains('Hello'));
      expect(run.toString(), contains('en-US'));
    });
  });
}
