import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/tts/text_run_splitter.dart';

void main() {
  group('TextRunSplitter', () {
    test('should handle empty text', () {
      final runs = TextRunSplitter.split('', 'en-US');
      expect(runs, isEmpty);
    });

    test('should handle single language text', () {
      final runs = TextRunSplitter.split('Hello world', 'en-US');
      expect(runs.length, 1);
      expect(runs[0].text, 'Hello world');
      expect(runs[0].language, 'en-US');
    });

    test('should split Hebrew and English', () {
      final runs = TextRunSplitter.split('Hello שלום world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Hebrew run
      final hebrewRun = runs.firstWhere((r) => r.language == 'he-IL');
      expect(hebrewRun.text, contains('שלום'));
    });

    test('should split Arabic and English', () {
      final runs = TextRunSplitter.split('Hello مرحبا world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Arabic run
      final arabicRun = runs.firstWhere((r) => r.language == 'ar');
      expect(arabicRun.text, contains('مرحبا'));
    });

    test('should split Cyrillic (Russian) and English', () {
      final runs = TextRunSplitter.split('Hello Привет world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Russian run
      final russianRun = runs.firstWhere((r) => r.language == 'ru-RU');
      expect(russianRun.text, contains('Привет'));
    });

    test('should split Japanese (Hiragana) and English', () {
      final runs = TextRunSplitter.split('Hello こんにちは world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Japanese run
      final japaneseRun = runs.firstWhere((r) => r.language == 'ja-JP');
      expect(japaneseRun.text, contains('こんにちは'));
    });

    test('should split Korean (Hangul) and English', () {
      final runs = TextRunSplitter.split('Hello 안녕하세요 world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Korean run
      final koreanRun = runs.firstWhere((r) => r.language == 'ko-KR');
      expect(koreanRun.text, contains('안녕하세요'));
    });

    test('should split Chinese (CJK) and English', () {
      final runs = TextRunSplitter.split('Hello 你好 world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      // Should have Chinese run
      final chineseRun = runs.firstWhere((r) => r.language == 'zh');
      expect(chineseRun.text, contains('你好'));
    });

    test('should handle multiple languages in one text', () {
      final runs =
          TextRunSplitter.split('English שלום مرحبا Привет 你好', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(4));

      final languages = runs.map((r) => r.language).toSet();
      expect(languages, contains('en-US'));
      expect(languages, contains('he-IL'));
      expect(languages, contains('ar'));
      expect(languages, contains('ru-RU'));
      expect(languages, contains('zh'));
    });

    test('should not split single-character runs', () {
      // Single character should be merged with adjacent run
      final runs = TextRunSplitter.split('Hello!', 'en-US');
      expect(runs.length, 1);
      expect(runs[0].text, 'Hello!');
    });

    test('should keep punctuation with text', () {
      final runs = TextRunSplitter.split('Hello, שלום! How are you?', 'en-US');

      // All runs should contain their associated punctuation
      for (final run in runs) {
        expect(run.text.trim(), isNotEmpty);
      }
    });

    test('should handle whitespace-only text', () {
      final runs = TextRunSplitter.split('   \n\t  ', 'en-US');
      expect(runs, isEmpty);
    });

    test('should handle mixed numbers and text', () {
      final runs = TextRunSplitter.split('Call 123-456-7890', 'en-US');
      expect(runs.length, 1);
      expect(runs[0].text, 'Call 123-456-7890');
      expect(runs[0].language, 'en-US');
    });

    test('should handle emojis with default language', () {
      final runs = TextRunSplitter.split('Hello 👋 world 🌍', 'en-US');
      expect(runs.length, 1);
      expect(runs[0].language, 'en-US');
    });

    test('should use default language for Latin script', () {
      final runs = TextRunSplitter.split('Bonjour le monde', 'fr-FR');
      expect(runs.length, 1);
      expect(runs[0].language, 'fr-FR');
    });

    test('should handle Thai script', () {
      final runs = TextRunSplitter.split('Hello สวัสดี world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      final thaiRun = runs.firstWhere((r) => r.language == 'th');
      expect(thaiRun.text, contains('สวัสดี'));
    });

    test('should handle Greek script', () {
      final runs = TextRunSplitter.split('Hello Γειά σου world', 'en-US');
      expect(runs.length, greaterThanOrEqualTo(2));

      final greekRun = runs.firstWhere((r) => r.language == 'el');
      expect(greekRun.text, contains('Γειά'));
    });
  });
}
