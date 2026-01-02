import 'dart:typed_data';

/// Request for text-to-speech synthesis
class TtsRequest {
  final String text;
  final String defaultLang;
  final double rate;
  final double pitch;
  final String voice;

  const TtsRequest({
    required this.text,
    required this.defaultLang,
    this.rate = 1.0,
    this.pitch = 1.0,
    this.voice = 'alloy',
  });
}

/// Audio data returned from TTS synthesis
class TtsAudio {
  final Uint8List bytes;
  final String mimeType;

  const TtsAudio({
    required this.bytes,
    required this.mimeType,
  });
}

/// Token for cancelling ongoing TTS operations
class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void reset() {
    _isCancelled = false;
  }
}

/// A run of text in a specific language
class TextRun {
  final String text;
  final String language;

  const TextRun({
    required this.text,
    required this.language,
  });

  @override
  String toString() => 'TextRun(text: "$text", language: $language)';
}
