// lib/services/poi_search_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/poi.dart';
import 'api_client.dart';
import 'poi_interest_scorer.dart';

/// Result from a POI search with relevance scoring
class PoiSearchResult {
  final Poi poi;
  final double relevanceScore;
  final String matchedText;

  PoiSearchResult({
    required this.poi,
    required this.relevanceScore,
    required this.matchedText,
  });
}

/// Service for searching POIs by name with context-aware relevance scoring
class PoiSearchService {
  final String lang;
  final ApiClient _apiClient;

  PoiSearchService(
      {this.lang = 'en', ApiClient? apiClient, http.Client? httpClient})
      : _apiClient = apiClient ?? HttpApiClient(httpClient ?? http.Client());

  /// Search for POIs by name with context-aware relevance scoring
  ///
  /// [query] - The search text (e.g., "Wailing Wall", "Стена Плача")
  /// [userLocation] - User's current location for distance-based relevance
  /// [mapBounds] - Current visible map bounds for area-based relevance
  /// [limit] - Maximum number of results to return (default: 10)
  ///
  /// Returns a list of search results sorted by relevance score (highest first)
  Future<List<PoiSearchResult>> searchPois({
    required String query,
    LatLng? userLocation,
    MapBounds? mapBounds,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Use Wikipedia's opensearch API for fuzzy, multi-language search
      final searchResults = await _searchWikipedia(query, limit: limit * 2);

      if (searchResults.isEmpty) {
        return [];
      }

      // Convert to POIs and calculate relevance scores
      final scoredResults = <PoiSearchResult>[];

      for (final result in searchResults) {
        // Get coordinates for the article
        final coordinates = await _getArticleCoordinates(result['title']);

        if (coordinates != null) {
          // Create POI from search result
          final poi = Poi(
            id: result['title'],
            name: result['title'],
            lat: coordinates['lat']!,
            lon: coordinates['lon']!,
            description: result['description'] ?? '',
            audio: '',
            interestScore: PoiInterestScorer.calculateScore(
              result['title'],
              result['description'],
            ),
            category: PoiInterestScorer.determineCategory(result['title']),
            interestLevel: PoiInterestLevel.medium, // Will be determined below
            isDescriptionLoaded: result['description'] != null,
          );

          // Determine interest level based on score and category
          final interestLevel = PoiInterestScorer.determineInterestLevel(
            poi.interestScore,
            poi.category,
          );

          // Update POI with correct interest level
          final updatedPoi = Poi(
            id: poi.id,
            name: poi.name,
            lat: poi.lat,
            lon: poi.lon,
            description: poi.description,
            audio: poi.audio,
            interestScore: poi.interestScore,
            category: poi.category,
            interestLevel: interestLevel,
            isDescriptionLoaded: poi.isDescriptionLoaded,
          );

          // Calculate relevance score based on context
          final relevanceScore = _calculateRelevanceScore(
            poi: updatedPoi,
            query: query,
            userLocation: userLocation,
            mapBounds: mapBounds,
            textMatchScore: result['matchScore'] ?? 1.0,
          );

          scoredResults.add(PoiSearchResult(
            poi: updatedPoi,
            relevanceScore: relevanceScore,
            matchedText: result['title'],
          ));
        }
      }

      // Sort by relevance score (highest first) and take top results
      scoredResults
          .sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      return scoredResults.take(limit).toList();
    } catch (e) {
      debugPrint('Error searching POIs: $e');
      return [];
    }
  }

  /// Search Wikipedia using opensearch API
  /// Returns list of articles with titles and descriptions
  Future<List<Map<String, dynamic>>> _searchWikipedia(
    String query, {
    int limit = 10,
  }) async {
    try {
      // Use opensearch API for fuzzy search with suggestions
      final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
        'action': 'opensearch',
        'format': 'json',
        'search': query,
        'limit': limit.toString(),
        'namespace': '0', // Main namespace (articles)
      });

      final responseBody = await _apiClient.get(url);
      final data = json.decode(responseBody);

      // OpenSearch returns: [query, [titles], [descriptions], [urls]]
      if (data is List && data.length >= 3) {
        final titles = data[1] as List;
        final descriptions = data[2] as List;

        final results = <Map<String, dynamic>>[];
        for (int i = 0; i < titles.length; i++) {
          results.add({
            'title': titles[i],
            'description': i < descriptions.length ? descriptions[i] : null,
            'matchScore':
                1.0 - (i / titles.length), // Higher for earlier results
          });
        }
        return results;
      }
    } catch (e) {
      debugPrint('Error searching Wikipedia: $e');
      // Return empty list instead of throwing to allow graceful fallback
    }

    return [];
  }

  /// Get coordinates for a Wikipedia article
  /// Returns null if the article doesn't have coordinates
  Future<Map<String, double>?> _getArticleCoordinates(String title) async {
    final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'coordinates',
      'titles': title,
    });

    try {
      final responseBody = await _apiClient.get(url);
      final data = json.decode(responseBody);

      final pages = data['query']['pages'] as Map<String, dynamic>;
      final page = pages.values.first;

      if (page['coordinates'] != null &&
          (page['coordinates'] as List).isNotEmpty) {
        final coords = page['coordinates'][0];
        return {
          'lat': coords['lat'].toDouble(),
          'lon': coords['lon'].toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Error fetching coordinates for $title: $e');
    }

    return null;
  }

  /// Calculate relevance score based on multiple factors
  ///
  /// Factors:
  /// - Text match quality (from Wikipedia search)
  /// - Distance from user location (if available)
  /// - Proximity to visible map area (if available)
  /// - POI interest score (inherent importance)
  ///
  /// Returns a score between 0.0 and 100.0+
  double _calculateRelevanceScore({
    required Poi poi,
    required String query,
    LatLng? userLocation,
    MapBounds? mapBounds,
    double textMatchScore = 1.0,
  }) {
    double score = 0.0;

    // 1. Text match quality (0-40 points)
    score += textMatchScore * 40.0;

    // 2. Inherent POI interest score (0-30 points)
    // Normalize interest score (typically 0-100) to 0-30
    score += (poi.interestScore / 100.0) * 30.0;

    // 3. Distance from user location (0-20 points)
    if (userLocation != null) {
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        poi.lat,
        poi.lon,
      );

      // Closer is better, max points within 1km, decreases logarithmically
      if (distance < 1000) {
        score += 20.0;
      } else if (distance < 10000) {
        // Within 10km
        score += 20.0 * (1.0 - (math.log(distance / 1000) / math.log(10)));
      } else if (distance < 100000) {
        // Within 100km
        score += 5.0 * (1.0 - ((distance - 10000) / 90000));
      }
      // Beyond 100km contributes 0 distance points
    }

    // 4. Visibility in current map bounds (0-10 points)
    if (mapBounds != null) {
      if (_isPoiInBounds(poi, mapBounds)) {
        score += 10.0; // POI is visible on current map
      } else {
        // Calculate how far from bounds
        final distanceFromBounds = _calculateDistanceFromBounds(poi, mapBounds);
        if (distanceFromBounds < 50000) {
          // Within 50km of visible area
          score += 5.0 * (1.0 - (distanceFromBounds / 50000));
        }
      }
    }

    return score;
  }

  /// Calculate distance between two points in meters using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Check if POI is within map bounds
  bool _isPoiInBounds(Poi poi, MapBounds bounds) {
    return poi.lat >= bounds.south &&
        poi.lat <= bounds.north &&
        poi.lon >= bounds.west &&
        poi.lon <= bounds.east;
  }

  /// Calculate approximate distance from POI to nearest point on map bounds
  double _calculateDistanceFromBounds(Poi poi, MapBounds bounds) {
    // Find nearest point on the rectangle to the POI
    final nearestLat = poi.lat.clamp(bounds.south, bounds.north);
    final nearestLon = poi.lon.clamp(bounds.west, bounds.east);

    return _calculateDistance(poi.lat, poi.lon, nearestLat, nearestLon);
  }
}

/// Helper class to represent map bounds
class MapBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  MapBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}
