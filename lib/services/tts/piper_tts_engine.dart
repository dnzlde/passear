import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine.dart';
import 'tts_models.dart';

/// Piper TTS engine using flutter_tts as fallback
class PiperTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  @override
  String get engineName => 'Piper TTS (fallback)';

  Future<void> _initialize() async {
    if (_isInitialized) return;

    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  @override
  Future<TtsAudio> synthesize(
    TtsRequest request, {
    CancellationToken? cancellationToken,
  }) async {
    await _initialize();

    // Check cancellation before starting
    if (cancellationToken?.isCancelled ?? false) {
      throw Exception('Synthesis cancelled before starting');
    }

    debugPrint('$engineName: Synthesizing text (${request.text.length} chars) '
        'in language ${request.defaultLang}');

    try {
      final startTime = DateTime.now();

      // Map language to supported flutter_tts locale
      final locale = _mapLanguageToLocale(request.defaultLang);
      await _tts.setLanguage(locale);

      // Set speech parameters
      await _tts.setSpeechRate(request.rate.clamp(0.0, 1.0));
      await _tts.setPitch(request.pitch.clamp(0.5, 2.0));

      // Note: flutter_tts doesn't provide direct audio bytes
      // In a real implementation, this would use platform channels
      // to get WAV data. For now, we'll return empty bytes as a placeholder
      // and the actual speech will happen through flutter_tts.speak()

      final duration = DateTime.now().difference(startTime);
      debugPrint(
          '$engineName: Synthesis completed in ${duration.inMilliseconds}ms');

      // Return empty audio data - the actual TTS will be handled by flutter_tts
      // This is a simplified fallback implementation
      return TtsAudio(
        bytes: Uint8List(0),
        mimeType: 'audio/wav',
      );
    } catch (e) {
      debugPrint('$engineName: Error: $e');
      rethrow;
    }
  }

  /// Map BCP-47 language code to flutter_tts locale
  String _mapLanguageToLocale(String language) {
    // Common language mappings
    final languageMap = {
      'en': 'en-US',
      'en-US': 'en-US',
      'en-GB': 'en-GB',
      'es': 'es-ES',
      'es-ES': 'es-ES',
      'es-MX': 'es-MX',
      'fr': 'fr-FR',
      'fr-FR': 'fr-FR',
      'de': 'de-DE',
      'de-DE': 'de-DE',
      'it': 'it-IT',
      'it-IT': 'it-IT',
      'pt': 'pt-PT',
      'pt-PT': 'pt-PT',
      'pt-BR': 'pt-BR',
      'ru': 'ru-RU',
      'ru-RU': 'ru-RU',
      'ja': 'ja-JP',
      'ja-JP': 'ja-JP',
      'ko': 'ko-KR',
      'ko-KR': 'ko-KR',
      'zh': 'zh-CN',
      'zh-CN': 'zh-CN',
      'zh-TW': 'zh-TW',
      'ar': 'ar-SA',
      'ar-SA': 'ar-SA',
      'he': 'he-IL',
      'he-IL': 'he-IL',
      'hi': 'hi-IN',
      'hi-IN': 'hi-IN',
      'th': 'th-TH',
      'th-TH': 'th-TH',
      'tr': 'tr-TR',
      'tr-TR': 'tr-TR',
      'pl': 'pl-PL',
      'pl-PL': 'pl-PL',
      'nl': 'nl-NL',
      'nl-NL': 'nl-NL',
      'sv': 'sv-SE',
      'sv-SE': 'sv-SE',
      'da': 'da-DK',
      'da-DK': 'da-DK',
      'fi': 'fi-FI',
      'fi-FI': 'fi-FI',
      'no': 'no-NO',
      'no-NO': 'no-NO',
      'el': 'el-GR',
      'el-GR': 'el-GR',
    };

    final mapped = languageMap[language];
    if (mapped != null) {
      return mapped;
    }

    // If not in map, check if it's already in locale format
    if (language.contains('-')) {
      return language;
    }

    // Default fallback to en-US
    debugPrint(
        '$engineName: Unknown language "$language", falling back to en-US');
    return 'en-US';
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _tts.stop();
  }
}
