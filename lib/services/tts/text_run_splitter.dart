import 'tts_models.dart';

/// Splits text into runs by Unicode script blocks for multilingual TTS
class TextRunSplitter {
  /// Split text by Unicode script blocks
  /// Returns list of TextRun objects with detected languages
  static List<TextRun> split(String text, String defaultLang) {
    if (text.isEmpty) return [];

    final runs = <_CharRun>[];
    final codeUnits = text.runes.toList();

    // First pass: detect language for each character
    for (int i = 0; i < codeUnits.length; i++) {
      final codePoint = codeUnits[i];
      final lang = _detectLanguage(codePoint, defaultLang);
      final char = String.fromCharCode(codePoint);

      if (runs.isEmpty || runs.last.language != lang) {
        runs.add(_CharRun(language: lang, chars: [char]));
      } else {
        runs.last.chars.add(char);
      }
    }

    // Second pass: merge runs intelligently
    // 1. Merge whitespace/punctuation between same-language runs
    // 2. Merge whitespace/punctuation with adjacent non-default language runs
    // 3. Merge single-character runs with adjacent runs
    // 4. Merge consecutive runs of the same language
    final mergedRuns = <_CharRun>[];
    for (int i = 0; i < runs.length; i++) {
      final run = runs[i];
      final text = run.chars.join();
      final isWhitespaceOrPunct =
          text.trim().isEmpty ||
          text.length == 1 &&
              RegExp(r'[\s\p{P}]', unicode: true).hasMatch(text);

      // If this is whitespace/punctuation and matches default language
      if (isWhitespaceOrPunct && run.language == defaultLang) {
        // Check if it's between two runs of the SAME non-default language
        // This fixes Hebrew/Arabic/etc phrase splitting: "word1 word2 word3"
        if (mergedRuns.isNotEmpty &&
            i + 1 < runs.length &&
            mergedRuns.last.language != defaultLang &&
            mergedRuns.last.language == runs[i + 1].language) {
          // Merge space with previous run, and it will connect to next
          mergedRuns.last.chars.add(text);
          continue;
        }
        // Try to merge with previous non-default run if exists
        else if (mergedRuns.isNotEmpty &&
            mergedRuns.last.language != defaultLang) {
          mergedRuns.last.chars.add(text);
          continue;
        }
        // Otherwise try to merge with next non-default run
        else if (i + 1 < runs.length && runs[i + 1].language != defaultLang) {
          runs[i + 1].chars.insert(0, text);
          continue;
        }
      }

      // If single character and not the only run, try to merge
      if (text.length == 1 && runs.length > 1 && !isWhitespaceOrPunct) {
        if (mergedRuns.isNotEmpty) {
          // Merge with previous run
          mergedRuns.last.chars.add(text);
        } else if (i + 1 < runs.length) {
          // Merge with next run
          runs[i + 1].chars.insert(0, text);
        } else {
          // Only run, keep it
          mergedRuns.add(run);
        }
      } else {
        // Check if we can merge with previous run of same language
        if (mergedRuns.isNotEmpty && mergedRuns.last.language == run.language) {
          // Merge with previous run of same language
          mergedRuns.last.chars.addAll(run.chars);
        } else {
          mergedRuns.add(run);
        }
      }
    }

    // Convert to TextRun objects
    return mergedRuns
        .map((run) => TextRun(text: run.chars.join(), language: run.language))
        .where((run) => run.text.trim().isNotEmpty)
        .toList();
  }

  /// Detect language from Unicode code point
  static String _detectLanguage(int codePoint, String defaultLang) {
    // Hebrew
    if (codePoint >= 0x0590 && codePoint <= 0x05FF) {
      return 'he-IL';
    }

    // Arabic
    if (codePoint >= 0x0600 && codePoint <= 0x06FF) {
      return 'ar';
    }

    // Cyrillic
    if (codePoint >= 0x0400 && codePoint <= 0x04FF) {
      return 'ru-RU';
    }

    // Hiragana
    if (codePoint >= 0x3040 && codePoint <= 0x309F) {
      return 'ja-JP';
    }

    // Katakana
    if (codePoint >= 0x30A0 && codePoint <= 0x30FF) {
      return 'ja-JP';
    }

    // Hangul (Korean)
    if (codePoint >= 0xAC00 && codePoint <= 0xD7AF) {
      return 'ko-KR';
    }

    // Hangul Jamo
    if (codePoint >= 0x1100 && codePoint <= 0x11FF) {
      return 'ko-KR';
    }

    // CJK Unified Ideographs (Chinese)
    if (codePoint >= 0x4E00 && codePoint <= 0x9FFF) {
      return 'zh';
    }

    // CJK Extension A
    if (codePoint >= 0x3400 && codePoint <= 0x4DBF) {
      return 'zh';
    }

    // Thai
    if (codePoint >= 0x0E00 && codePoint <= 0x0E7F) {
      return 'th';
    }

    // Devanagari (Hindi)
    if (codePoint >= 0x0900 && codePoint <= 0x097F) {
      return 'hi';
    }

    // Bengali
    if (codePoint >= 0x0980 && codePoint <= 0x09FF) {
      return 'bn';
    }

    // Tamil
    if (codePoint >= 0x0B80 && codePoint <= 0x0BFF) {
      return 'ta';
    }

    // Telugu
    if (codePoint >= 0x0C00 && codePoint <= 0x0C7F) {
      return 'te';
    }

    // Greek
    if (codePoint >= 0x0370 && codePoint <= 0x03FF) {
      return 'el';
    }

    // Armenian
    if (codePoint >= 0x0530 && codePoint <= 0x058F) {
      return 'hy';
    }

    // Georgian
    if (codePoint >= 0x10A0 && codePoint <= 0x10FF) {
      return 'ka';
    }

    // Default to provided language for Latin, punctuation, numbers, etc.
    return defaultLang;
  }
}

/// Internal class for building character runs
class _CharRun {
  final String language;
  final List<String> chars;

  _CharRun({required this.language, required this.chars});
}
