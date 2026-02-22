// lib/services/overpass_poi_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/poi.dart';
import 'api_client.dart';
import 'poi_telemetry.dart';

/// Overpass API service for fetching POIs from OpenStreetMap
/// Uses the Overpass API to query OSM data for points of interest
class OverpassPoiService {
  final ApiClient _apiClient;

  // Public Overpass API endpoint
  static const String _baseUrl = 'overpass-api.de';
  // Keep timeout short to avoid long UI stalls when Overpass is overloaded.
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const int _maxAttempts = 3;

  // Exponential backoff parameters
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 8);

  final Random _random;

  OverpassPoiService({ApiClient? apiClient, Random? random})
      : _apiClient = apiClient ?? HttpApiClient(null),
        _random = random ?? Random();

  /// Fetch POIs within bounds using Overpass API
  Future<List<Poi>> fetchPoisInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int maxResults = 50,
    ApiCancellationToken? cancelToken,
    PoiRequestTrace? trace,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        // Build Overpass QL query for tourism and historic POIs
        final query = _buildOverpassQuery(north, south, east, west, maxResults);

        debugPrint('Overpass API query: $query');

        // Build the URI with query parameters
        final uri = Uri.https(_baseUrl, '/api/interpreter', {'data': query});

        final responseBody =
            await _apiClient.get(uri, cancelToken: cancelToken).timeout(
                  _requestTimeout,
                  onTimeout: () => throw TimeoutException(
                    'Overpass API request timed out after ${_requestTimeout.inSeconds}s',
                  ),
                );
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

        // If request was cancelled, don't retry - rethrow immediately
        if (e is ApiRequestCancelledException) {
          rethrow;
        }

        final errorClass = e.runtimeType.toString();
        trace?.recordFetchAttempt(attempt: attempt, errorClass: errorClass);
        debugPrint('Error fetching Overpass POIs (attempt $attempt): $e');

        final shouldRetry = attempt < _maxAttempts && _isRetryableError(e);
        if (shouldRetry) {
          // Check if cancelled before retrying
          if (cancelToken?.isCancelled ?? false) {
            throw ApiRequestCancelledException();
          }

          final delay = _calculateDelay(attempt);
          debugPrint('Retrying in ${delay.inMilliseconds}ms...');
          await Future.delayed(delay);

          // Check if cancelled after delay
          if (cancelToken?.isCancelled ?? false) {
            throw ApiRequestCancelledException();
          }

          continue;
        }
      }
    }

    if (lastError != null) throw lastError;
    throw StateError('Overpass fetch failed without captured error');
  }

  bool _isRetryableError(Object error) {
    final message = error.toString();
    return message.contains('HTTP 429') ||
        _is5xxError(message) ||
        error is TimeoutException;
  }

  static bool _is5xxError(String message) {
    final match = RegExp(r'HTTP 5\d\d').firstMatch(message);
    return match != null;
  }

  /// Calculates retry delay using exponential backoff with jitter.
  /// delay = min(maxDelay, baseDelay * 2^(attempt-1)) * jitter
  /// where jitter is a random factor in [0.5, 1.0).
  @visibleForTesting
  Duration calculateDelay(int attempt) => _calculateDelay(attempt);

  Duration _calculateDelay(int attempt) {
    final exponentialMs =
        _baseDelay.inMilliseconds * pow(2, attempt - 1).toInt();
    final cappedMs = min(exponentialMs, _maxDelay.inMilliseconds);
    final jitter = 0.5 + _random.nextDouble() * 0.5;
    return Duration(milliseconds: (cappedMs * jitter).round());
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
