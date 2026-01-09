import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'tts_engine.dart';
import 'tts_models.dart';

/// OpenAI TTS engine using cloud API
class OpenAiTtsEngine implements TtsEngine {
  final String apiKey;
  static const String _endpoint = 'https://api.openai.com/v1/audio/speech';
  static const Duration _timeout = Duration(seconds: 30);

  OpenAiTtsEngine({required this.apiKey});

  @override
  String get engineName => 'OpenAI TTS';

  @override
  Future<TtsAudio> synthesize(
    TtsRequest request, {
    CancellationToken? cancellationToken,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('OpenAI API key is not configured');
    }

    // Check cancellation before starting
    if (cancellationToken?.isCancelled ?? false) {
      throw Exception('Synthesis cancelled before starting');
    }

    debugPrint('$engineName: Synthesizing text (${request.text.length} chars) '
        'in language ${request.defaultLang}');

    try {
      final startTime = DateTime.now();

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'tts-1',
              'voice': request.voice,
              'input': request.text,
              'speed': request.rate.clamp(0.25, 4.0),
            }),
          )
          .timeout(_timeout);

      final duration = DateTime.now().difference(startTime);

      // Check cancellation after request
      if (cancellationToken?.isCancelled ?? false) {
        throw Exception('Synthesis cancelled after request');
      }

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        debugPrint(
            '$engineName: Synthesis completed in ${duration.inMilliseconds}ms, '
            '${bytes.length} bytes');
        return TtsAudio(
          bytes: Uint8List.fromList(bytes),
          mimeType: 'audio/mpeg',
        );
      } else if (response.statusCode == 401) {
        throw Exception(
            'OpenAI API authentication failed (401): Invalid API key');
      } else if (response.statusCode == 429) {
        throw Exception('OpenAI API rate limit exceeded (429)');
      } else if (response.statusCode >= 500) {
        throw Exception(
            'OpenAI API server error (${response.statusCode}): ${response.body}');
      } else {
        throw Exception(
            'OpenAI API request failed (${response.statusCode}): ${response.body}');
      }
    } on http.ClientException catch (e) {
      debugPrint('$engineName: Network error: $e');
      throw Exception('OpenAI API network error: $e');
    } catch (e) {
      debugPrint('$engineName: Error: $e');
      rethrow;
    }
  }
}
