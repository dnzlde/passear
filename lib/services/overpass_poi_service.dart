// lib/services/overpass_poi_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/poi.dart';
import 'api_client.dart';

/// Overpass API service for fetching POIs from OpenStreetMap
/// Uses the Overpass API to query OSM data for points of interest
class OverpassPoiService {
  final ApiClient _apiClient;
  Future<void> _requestQueue = Future<void>.value();
  DateTime _lastRequestTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  // Public Overpass API endpoint
  static const String _baseUrl = 'overpass-api.de';
  static const Duration _minRequestInterval = Duration(milliseconds: 700);
  static const Duration _retryDelay = Duration(seconds: 1);
  static const int _maxAttempts = 2;

  OverpassPoiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? HttpApiClient(null);

  /// Fetch POIs within bounds using Overpass API
  Future<List<Poi>> fetchPoisInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int maxResults = 50,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        // Build Overpass QL query for tourism and historic POIs
        final query = _buildOverpassQuery(north, south, east, west, maxResults);

        debugPrint('Overpass API query: $query');

        // Build the URI with query parameters
        final uri = Uri.https(_baseUrl, '/api/interpreter', {'data': query});

        final responseBody = await _enqueueOverpassRequest(() {
          return _apiClient.get(uri);
        });
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];

        final pois = <Poi>[];
        for (final element in elements) {
          if (element is Map<String, dynamic>) {
            final poi = _parsePoi(element);
            if (poi != null) {
              pois.add(poi);
            }
          }
        }

        debugPrint('Overpass API returned ${pois.length} POIs');
        return pois;
      } catch (e) {
        lastError = e;
        debugPrint('Error fetching Overpass POIs (attempt $attempt): $e');

        final shouldRetry = attempt < _maxAttempts && _isRetryableError(e);
        if (shouldRetry) {
          await Future.delayed(_retryDelay);
          continue;
        }
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('Overpass fetch failed without captured error');
  }

  Future<T> _enqueueOverpassRequest<T>(Future<T> Function() request) {
    final completer = Completer<T>();

    _requestQueue = _requestQueue.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequestTimestamp);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }

      try {
        final result = await request();
        _lastRequestTimestamp = DateTime.now();
        completer.complete(result);
      } catch (e, stackTrace) {
        _lastRequestTimestamp = DateTime.now();
        completer.completeError(e, stackTrace);
      }
    });

    return completer.future;
  }

  bool _isRetryableError(Object error) {
    final message = error.toString();
    return message.contains('HTTP 429') ||
        message.contains('HTTP 504') ||
        error is TimeoutException;
  }

  /// Build Overpass QL query for POIs
  String _buildOverpassQuery(
    double north,
    double south,
    double east,
    double west,
    int limit,
  ) {
    // Query for tourism and historic nodes/ways in the bounding box
    return '''
[out:json][timeout:25];
(
  node["tourism"~"museum|attraction|viewpoint|artwork|gallery"]($south,$west,$north,$east);
  node["historic"~"monument|memorial|archaeological_site|castle|ruins"]($south,$west,$north,$east);
  node["amenity"~"theatre|arts_centre"]($south,$west,$north,$east);
  way["tourism"~"museum|attraction|viewpoint|artwork|gallery"]($south,$west,$north,$east);
  way["historic"~"monument|memorial|archaeological_site|castle|ruins"]($south,$west,$north,$east);
  way["amenity"~"theatre|arts_centre"]($south,$west,$north,$east);
);
out center $limit;
''';
  }

  /// Parse a POI from Overpass API element
  Poi? _parsePoi(Map<String, dynamic> element) {
    try {
      final tags = element['tags'] as Map<String, dynamic>?;
      if (tags == null) return null;

      final name = tags['name'] as String?;
      if (name == null || name.isEmpty) return null;

      // Get coordinates
      double? lat;
      double? lon;

      if (element['type'] == 'node') {
        lat = element['lat'] as double?;
        lon = element['lon'] as double?;
      } else if (element['type'] == 'way') {
        // For ways, use center coordinates
        final center = element['center'] as Map<String, dynamic>?;
        lat = center?['lat'] as double?;
        lon = center?['lon'] as double?;
      }

      if (lat == null || lon == null) return null;

      final id = element['id']?.toString() ?? '';
      final category = _categorizeFromTags(tags);
      final description = _buildDescription(tags);

      // Calculate interest score based on tags
      final interestScore = _calculateInterestScore(tags);
      final interestLevel = _getInterestLevel(interestScore);

      return Poi(
        id: 'osm_$id',
        name: name,
        lat: lat,
        lon: lon,
        description: description,
        audio: '',
        interestScore: interestScore,
        category: category,
        interestLevel: interestLevel,
        isDescriptionLoaded: description.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error parsing Overpass POI: $e');
      return null;
    }
  }

  /// Categorize POI based on OSM tags
  PoiCategory _categorizeFromTags(Map<String, dynamic> tags) {
    final tourism = tags['tourism'] as String?;
    final historic = tags['historic'] as String?;
    final amenity = tags['amenity'] as String?;

    if (tourism == 'museum' || amenity == 'arts_centre') {
      return PoiCategory.museum;
    } else if (tourism == 'gallery') {
      return PoiCategory.gallery;
    } else if (historic == 'monument' || historic == 'memorial') {
      return PoiCategory.monument;
    } else if (historic == 'castle' ||
        historic == 'ruins' ||
        historic == 'archaeological_site') {
      return PoiCategory.historicalSite;
    } else if (amenity == 'theatre') {
      return PoiCategory.theater;
    } else if (tourism == 'attraction' || tourism == 'viewpoint') {
      return PoiCategory.landmark;
    } else if (tourism == 'artwork') {
      return PoiCategory.architecture;
    }

    return PoiCategory.generic;
  }

  /// Build description from OSM tags
  String _buildDescription(Map<String, dynamic> tags) {
    final parts = <String>[];

    final tourism = tags['tourism'] as String?;
    final historic = tags['historic'] as String?;
    final amenity = tags['amenity'] as String?;
    final description = tags['description'] as String?;
    final wikipedia = tags['wikipedia'] as String?;

    if (tourism != null) parts.add('Tourism: $tourism');
    if (historic != null) parts.add('Historic: $historic');
    if (amenity != null) parts.add('Amenity: $amenity');
    if (description != null) parts.add(description);
    if (wikipedia != null) parts.add('Wikipedia: $wikipedia');

    return parts.join('\n');
  }

  /// Calculate interest score based on tags
  double _calculateInterestScore(Map<String, dynamic> tags) {
    double score = 0.5; // Base score

    // Increase score for certain types
    if (tags['tourism'] == 'museum') score += 0.3;
    if (tags['tourism'] == 'attraction') score += 0.2;
    if (tags['historic'] != null) score += 0.2;
    if (tags['wikipedia'] != null) score += 0.2;
    if (tags['wikidata'] != null) score += 0.1;
    if (tags['heritage'] != null) score += 0.15;
    if (tags['unesco'] == 'yes') score += 0.3;

    return score.clamp(0.0, 1.0);
  }

  /// Get interest level from score
  PoiInterestLevel _getInterestLevel(double score) {
    if (score >= 0.75) return PoiInterestLevel.high;
    if (score >= 0.5) return PoiInterestLevel.medium;
    return PoiInterestLevel.low;
  }
}
