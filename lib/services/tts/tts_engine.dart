import 'tts_models.dart';

/// Abstract interface for TTS engines
abstract class TtsEngine {
  /// Synthesize speech from text
  ///
  /// Returns [TtsAudio] containing audio bytes and MIME type
  /// Throws exception on error (for fallback handling)
  Future<TtsAudio> synthesize(
    TtsRequest request, {
    CancellationToken? cancellationToken,
  });

  /// Get the name of this engine for logging
  String get engineName;
}
