// test/services/poi_interest_scorer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_interest_scorer.dart';
import 'package:passear/models/poi.dart';

void main() {
  group('PoiInterestScorer', () {
    test('should score museum titles highly', () {
      final score = PoiInterestScorer.calculateScore('Tel Aviv Museum of Art', null);
      expect(score, greaterThan(25.0));
    });

    test('should score cathedral titles highly', () {
      final score = PoiInterestScorer.calculateScore('Notre-Dame Cathedral', null);
      expect(score, greaterThan(25.0));
    });

    test('should score palace titles highly', () {
      final score = PoiInterestScorer.calculateScore('Buckingham Palace', null);
      expect(score, greaterThan(25.0));
    });

    test('should score generic locations lower', () {
      final score = PoiInterestScorer.calculateScore('Main Street', null);
      expect(score, lessThan(10.0));
    });

    test('should boost score for longer descriptions', () {
      const shortDesc = 'A building.';
      const longDesc = 'The Tel Aviv Museum of Art is a major art museum in Tel Aviv, Israel. Founded in 1932, it houses one of Israel\'s largest collections of modern and contemporary art. The museum is located in the cultural district of the city and attracts thousands of visitors annually.';
      
      final scoreShort = PoiInterestScorer.calculateScore('Museum', shortDesc);
      final scoreLong = PoiInterestScorer.calculateScore('Museum', longDesc);
      
      expect(scoreLong, greaterThan(scoreShort));
    });

    test('should categorize museums correctly', () {
      final category = PoiInterestScorer.determineCategory('Tel Aviv Museum of Art');
      expect(category, equals(PoiCategory.museum));
    });

    test('should categorize religious sites correctly', () {
      final category = PoiInterestScorer.determineCategory('St. Patrick\'s Cathedral');
      expect(category, equals(PoiCategory.religiousSite));
    });

    test('should categorize historical sites correctly', () {
      final category = PoiInterestScorer.determineCategory('Windsor Castle');
      expect(category, equals(PoiCategory.historicalSite));
    });

    test('should categorize monuments correctly', () {
      final category = PoiInterestScorer.determineCategory('Lincoln Memorial');
      expect(category, equals(PoiCategory.monument));
    });

    test('should categorize universities correctly', () {
      final category = PoiInterestScorer.determineCategory('Harvard University');
      expect(category, equals(PoiCategory.university));
    });

    test('should categorize generic locations as generic', () {
      final category = PoiInterestScorer.determineCategory('Main Street');
      expect(category, equals(PoiCategory.generic));
    });

    test('should determine high interest level for high scores', () {
      final level = PoiInterestScorer.determineInterestLevel(45.0, PoiCategory.generic);
      expect(level, equals(PoiInterestLevel.high));
    });

    test('should determine high interest level for museums regardless of score', () {
      final level = PoiInterestScorer.determineInterestLevel(10.0, PoiCategory.museum);
      expect(level, equals(PoiInterestLevel.high));
    });

    test('should determine medium interest level for medium scores', () {
      final level = PoiInterestScorer.determineInterestLevel(25.0, PoiCategory.generic);
      expect(level, equals(PoiInterestLevel.medium));
    });

    test('should determine low interest level for low scores', () {
      final level = PoiInterestScorer.determineInterestLevel(5.0, PoiCategory.generic);
      expect(level, equals(PoiInterestLevel.low));
    });

    test('should boost score for historical descriptions', () {
      const historicalDesc = 'Built in the 12th century, this ancient cathedral is a UNESCO heritage site and significant historical landmark.';
      final score = PoiInterestScorer.calculateScore('Ancient Cathedral', historicalDesc);
      expect(score, greaterThan(40.0));
    });

    test('should handle null descriptions gracefully', () {
      final score = PoiInterestScorer.calculateScore('Test Location', null);
      expect(score, isA<double>());
      expect(score, greaterThanOrEqualTo(0.0));
    });

    test('should handle empty descriptions gracefully', () {
      final score = PoiInterestScorer.calculateScore('Test Location', '');
      expect(score, isA<double>());
      expect(score, greaterThanOrEqualTo(0.0));
    });

    test('should boost score for descriptive titles', () {
      final shortScore = PoiInterestScorer.calculateScore('Museum', null);
      final longScore = PoiInterestScorer.calculateScore('National Museum of Natural History and Science', null);
      expect(longScore, greaterThan(shortScore));
    });

    test('should cap scores at maximum value', () {
      const veryLongDesc = 'Built in the ancient medieval 12th century, this famous notable significant important UNESCO heritage site is a historical landmark monument with architecture that was constructed and founded by famous builders.';
      final score = PoiInterestScorer.calculateScore('Historic Cathedral Museum Palace', veryLongDesc);
      expect(score, lessThanOrEqualTo(100.0));
    });
  });
}