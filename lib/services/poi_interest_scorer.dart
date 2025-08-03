// lib/services/poi_interest_scorer.dart
import '../models/poi.dart';

class PoiInterestScorer {
  static const double _maxScore = 100.0;

  /// High-value keywords that indicate significant POIs
  static const Map<String, double> _highValueKeywords = {
    'museum': 25.0,
    'palace': 25.0,
    'cathedral': 25.0,
    'church': 20.0,
    'temple': 20.0,
    'mosque': 20.0,
    'monument': 20.0,
    'memorial': 20.0,
    'castle': 25.0,
    'fortress': 20.0,
    'university': 15.0,
    'theater': 15.0,
    'theatre': 15.0,
    'gallery': 15.0,
    'library': 15.0,
    'park': 10.0,
    'garden': 10.0,
    'bridge': 10.0,
    'tower': 15.0,
    'hall': 10.0,
    'center': 5.0,
    'centre': 5.0,
    'square': 10.0,
    'station': 5.0,
    'airport': 5.0,
  };

  /// Medium-value keywords
  static const Map<String, double> _mediumValueKeywords = {
    'building': 5.0,
    'street': 3.0,
    'road': 2.0,
    'school': 5.0,
    'hospital': 3.0,
    'hotel': 2.0,
    'restaurant': 2.0,
    'shop': 1.0,
    'store': 1.0,
  };

  /// Categories and their base scores
  static const Map<PoiCategory, double> _categoryScores = {
    PoiCategory.museum: 25.0,
    PoiCategory.historicalSite: 25.0,
    PoiCategory.landmark: 20.0,
    PoiCategory.religiousSite: 20.0,
    PoiCategory.monument: 20.0,
    PoiCategory.university: 15.0,
    PoiCategory.theater: 15.0,
    PoiCategory.gallery: 15.0,
    PoiCategory.architecture: 15.0,
    PoiCategory.park: 10.0,
    PoiCategory.generic: 0.0,
  };

  /// Calculate interest score for a POI based on title and description
  static double calculateScore(String title, String? description) {
    double score = 0.0;

    // Title analysis - most important factor
    score += _analyzeTitleKeywords(title) * 1.5;

    // Description quality score
    if (description != null && description.isNotEmpty) {
      score += _analyzeDescriptionQuality(description);
    }

    // Coordinate precision bonus (handled in WikipediaPoiService)
    
    return score.clamp(0.0, _maxScore);
  }

  /// Determine POI category based on title keywords
  static PoiCategory determineCategory(String title) {
    final titleLower = title.toLowerCase();

    if (_containsAny(titleLower, ['museum', 'gallery', 'exhibition'])) {
      return PoiCategory.museum;
    }
    if (_containsAny(titleLower, ['cathedral', 'church', 'temple', 'mosque', 'synagogue'])) {
      return PoiCategory.religiousSite;
    }
    if (_containsAny(titleLower, ['palace', 'castle', 'fortress', 'citadel'])) {
      return PoiCategory.historicalSite;
    }
    if (_containsAny(titleLower, ['monument', 'memorial', 'statue'])) {
      return PoiCategory.monument;
    }
    if (_containsAny(titleLower, ['university', 'college', 'institute'])) {
      return PoiCategory.university;
    }
    if (_containsAny(titleLower, ['theater', 'theatre', 'opera', 'concert'])) {
      return PoiCategory.theater;
    }
    if (_containsAny(titleLower, ['park', 'garden', 'botanical'])) {
      return PoiCategory.park;
    }
    if (_containsAny(titleLower, ['tower', 'bridge', 'building', 'architecture'])) {
      return PoiCategory.architecture;
    }
    if (_containsAny(titleLower, ['landmark', 'site', 'historical', 'heritage'])) {
      return PoiCategory.landmark;
    }

    return PoiCategory.generic;
  }

  /// Determine interest level based on score and category
  static PoiInterestLevel determineInterestLevel(double score, PoiCategory category) {
    // High interest: Premium POIs
    if (score >= 40.0 || 
        category == PoiCategory.museum ||
        category == PoiCategory.historicalSite ||
        category == PoiCategory.landmark) {
      return PoiInterestLevel.high;
    }
    
    // Medium interest: Notable POIs
    if (score >= 20.0 ||
        category == PoiCategory.religiousSite ||
        category == PoiCategory.monument ||
        category == PoiCategory.architecture) {
      return PoiInterestLevel.medium;
    }

    // Low interest: Everything else
    return PoiInterestLevel.low;
  }

  static double _analyzeTitleKeywords(String title) {
    final titleLower = title.toLowerCase();
    double score = 0.0;

    // Check high-value keywords
    for (final entry in _highValueKeywords.entries) {
      if (titleLower.contains(entry.key)) {
        score += entry.value;
      }
    }

    // Check medium-value keywords (only if no high-value found)
    if (score == 0) {
      for (final entry in _mediumValueKeywords.entries) {
        if (titleLower.contains(entry.key)) {
          score += entry.value;
        }
      }
    }

    // Bonus for descriptive titles (longer, more specific)
    if (title.length > 20) score += 5.0;
    if (title.split(' ').length > 3) score += 5.0;

    return score;
  }

  static double _analyzeDescriptionQuality(String description) {
    double score = 0.0;

    // Length bonus - longer descriptions indicate more notable places
    if (description.length > 200) {
      score += 15.0;
    } else if (description.length > 100) {
      score += 10.0;
    } else if (description.length > 50) {
      score += 5.0;
    }

    // Content quality indicators
    final descLower = description.toLowerCase();
    
    // Historical/cultural keywords
    if (_containsAny(descLower, ['built', 'constructed', 'founded', 'established'])) {
      score += 5.0;
    }
    if (_containsAny(descLower, ['century', 'historical', 'ancient', 'medieval'])) {
      score += 5.0;
    }
    if (_containsAny(descLower, ['famous', 'notable', 'important', 'significant'])) {
      score += 5.0;
    }
    if (_containsAny(descLower, ['unesco', 'heritage', 'landmark', 'monument'])) {
      score += 10.0;
    }

    return score;
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}