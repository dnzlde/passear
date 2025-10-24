// lib/services/wikipedia_poi_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'poi_interest_scorer.dart';
import '../models/poi.dart';

class WikipediaPoi {
  final String title;
  final double lat;
  final double lon;
  String? description;
  double interestScore;
  PoiCategory category;
  PoiInterestLevel interestLevel;

  WikipediaPoi({
    required this.title,
    required this.lat,
    required this.lon,
    this.description,
    this.interestScore = 0.0,
    this.category = PoiCategory.generic,
    this.interestLevel = PoiInterestLevel.low,
  });
}

class WikipediaPoiService {
  final String lang;
  final ApiClient _apiClient;
  final Map<String, String> _descriptionCache = {};
  final Map<String, List<WikipediaPoi>> _searchCache = {};

  WikipediaPoiService({this.lang = 'en', ApiClient? apiClient})
    : _apiClient = apiClient ?? HttpApiClient(http.Client());

  /// Fetch POIs within rectangular bounds (north, south, east, west)
  Future<List<WikipediaPoi>> fetchPoisInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int maxResults = 20,
  }) async {
    final cacheKey =
        '${north.toStringAsFixed(4)},${south.toStringAsFixed(4)},${east.toStringAsFixed(4)},${west.toStringAsFixed(4)}';

    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // Calculate center and radius for API call
    final centerLat = (north + south) / 2;
    final centerLon = (east + west) / 2;

    // Calculate radius to cover the entire rectangular bounds
    final radius = _calculateRadiusForBounds(north, south, east, west);

    // Fetch POIs with larger limit to allow for filtering
    final pois = await fetchNearbyPois(
      centerLat,
      centerLon,
      radius: radius,
      limit: math.max(maxResults * 3, 30), // Fetch more to filter better
    );

    // Filter POIs to only include those within the actual bounds
    final filteredPois = pois
        .where(
          (poi) =>
              poi.lat >= south &&
              poi.lat <= north &&
              poi.lon >= west &&
              poi.lon <= east,
        )
        .toList();

    // Only enrich with basic scoring and categories, not descriptions
    await _enrichPoisBasic(filteredPois);

    // Sort by interest score and take top results
    filteredPois.sort((a, b) => b.interestScore.compareTo(a.interestScore));
    final result = filteredPois.take(maxResults).toList();

    _searchCache[cacheKey] = result;
    return result;
  }

  Future<List<WikipediaPoi>> fetchNearbyPois(
    double lat,
    double lon, {
    int radius = 1000,
    int limit = 10,
  }) async {
    if (radius > 10000) radius = 10000;
    final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'list': 'geosearch',
      'gscoord': '$lat|$lon',
      'gsradius': radius.toString(),
      'gslimit': limit.toString(),
    });

    final responseBody = await _apiClient.get(url);
    final data = json.decode(responseBody);
    final query = data['query'];
    if (query == null) return [];
    final results = query['geosearch'] as List?;
    if (results == null) return [];
    return results.map((e) {
      return WikipediaPoi(title: e['title'], lat: e['lat'], lon: e['lon']);
    }).toList();
  }

  Future<String?> fetchDescription(String title) async {
    if (_descriptionCache.containsKey(title)) {
      return _descriptionCache[title];
    }

    final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'extracts',
      'exintro': '1',
      'explaintext': '1',
      'titles': title,
    });

    try {
      final responseBody = await _apiClient.get(url);
      final data = json.decode(responseBody);
      final pages = data['query']['pages'] as Map<String, dynamic>;
      final page = pages.values.first;
      final description = page['extract'];

      if (description != null) {
        _descriptionCache[title] = description;
      }

      return description;
    } catch (e) {
      return null;
    }
  }

  Future<List<WikipediaPoi>> fetchNearbyWithDescriptions(
    double lat,
    double lon, {
    int radius = 1000,
    int limit = 10,
  }) async {
    final pois = await fetchNearbyPois(lat, lon, radius: radius, limit: limit);
    await _enrichPoisWithDescriptionsAndScores(pois);
    return pois;
  }

  /// Enhanced method that returns intelligent POIs with scoring for bounds
  Future<List<WikipediaPoi>> fetchIntelligentPoisInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int maxResults = 20,
  }) async {
    final pois = await fetchPoisInBounds(
      north: north,
      south: south,
      east: east,
      west: west,
      maxResults: maxResults * 2, // Get more for better filtering
    );

    // Apply additional intelligent filtering
    final highQualityPois = pois
        .where((poi) => poi.interestScore >= 10.0)
        .toList();

    // If we have enough high-quality POIs, return them
    if (highQualityPois.length >= maxResults) {
      return highQualityPois.take(maxResults).toList();
    }

    // Otherwise, ensure geographic distribution and mix of interest levels
    return _ensureGeographicDistribution(
      pois,
      maxResults,
      north,
      south,
      east,
      west,
    );
  }

  int _calculateRadiusForBounds(
    double north,
    double south,
    double east,
    double west,
  ) {
    // Calculate the diagonal distance of the rectangle and use it as radius
    final latDiff = north - south;
    final lonDiff = east - west;

    // Approximate conversion: 1 degree ≈ 111 km
    final latDistance = latDiff * 111000; // meters
    final lonDistance =
        lonDiff * 111000 * math.cos((north + south) / 2 * math.pi / 180);

    final diagonalDistance = math.sqrt(
      latDistance * latDistance + lonDistance * lonDistance,
    );

    // Use diagonal distance as radius, with some padding
    return (diagonalDistance * 0.6).round().clamp(500, 10000);
  }

  Future<void> _enrichPoisWithDescriptionsAndScores(
    List<WikipediaPoi> pois,
  ) async {
    for (final poi in pois) {
      poi.description = await fetchDescription(poi.title);
      poi.interestScore = PoiInterestScorer.calculateScore(
        poi.title,
        poi.description,
      );
      poi.category = PoiInterestScorer.determineCategory(poi.title);
      poi.interestLevel = PoiInterestScorer.determineInterestLevel(
        poi.interestScore,
        poi.category,
      );
    }
  }

  /// Enrich POIs with basic information (scores, categories) without descriptions
  /// This is used for initial map loading to improve performance
  Future<void> _enrichPoisBasic(List<WikipediaPoi> pois) async {
    for (final poi in pois) {
      // Calculate score based on title only for basic enrichment
      poi.interestScore = PoiInterestScorer.calculateScore(poi.title, null);
      poi.category = PoiInterestScorer.determineCategory(poi.title);
      poi.interestLevel = PoiInterestScorer.determineInterestLevel(
        poi.interestScore,
        poi.category,
      );
      // Description is null - will be loaded on-demand
      poi.description = null;
    }
  }

  /// Enrich a single POI with its description (for on-demand loading)
  Future<void> enrichPoiWithDescription(WikipediaPoi poi) async {
    if (poi.description == null) {
      poi.description = await fetchDescription(poi.title);
      // Recalculate score with description for more accurate scoring
      poi.interestScore = PoiInterestScorer.calculateScore(
        poi.title,
        poi.description,
      );
      poi.interestLevel = PoiInterestScorer.determineInterestLevel(
        poi.interestScore,
        poi.category,
      );
    }
  }

  List<WikipediaPoi> _ensureGeographicDistribution(
    List<WikipediaPoi> pois,
    int maxResults,
    double north,
    double south,
    double east,
    double west,
  ) {
    if (pois.length <= maxResults) return pois;

    // Divide the area into a grid and try to get POIs from different sections
    const gridSize = 3; // 3x3 grid
    final latStep = (north - south) / gridSize;
    final lonStep = (east - west) / gridSize;

    final distributed = <WikipediaPoi>[];
    final remainingPois = List<WikipediaPoi>.from(pois);

    // Try to get at least one POI from each grid cell
    for (int i = 0; i < gridSize && distributed.length < maxResults; i++) {
      for (int j = 0; j < gridSize && distributed.length < maxResults; j++) {
        final cellSouth = south + i * latStep;
        final cellNorth = south + (i + 1) * latStep;
        final cellWest = west + j * lonStep;
        final cellEast = west + (j + 1) * lonStep;

        final poisInCell = remainingPois
            .where(
              (poi) =>
                  poi.lat >= cellSouth &&
                  poi.lat < cellNorth &&
                  poi.lon >= cellWest &&
                  poi.lon < cellEast,
            )
            .toList();

        if (poisInCell.isNotEmpty) {
          // Take the highest-scored POI from this cell
          poisInCell.sort((a, b) => b.interestScore.compareTo(a.interestScore));
          distributed.add(poisInCell.first);
          remainingPois.remove(poisInCell.first);
        }
      }
    }

    // Fill remaining slots with highest-scored POIs
    remainingPois.sort((a, b) => b.interestScore.compareTo(a.interestScore));
    distributed.addAll(remainingPois.take(maxResults - distributed.length));

    return distributed.take(maxResults).toList();
  }

  /// Clear caches (useful for testing or memory management)
  void clearCaches() {
    _descriptionCache.clear();
    _searchCache.clear();
  }
}
