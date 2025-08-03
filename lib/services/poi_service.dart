// lib/services/poi_service.dart
import '../models/poi.dart';
import 'wikipedia_poi_service.dart';
import 'api_client.dart';

class PoiService {
  final WikipediaPoiService _wikiService;

  PoiService({ApiClient? apiClient}) 
      : _wikiService = WikipediaPoiService(apiClient: apiClient);

  /// Fetch POIs within rectangular bounds using intelligent scoring
  Future<List<Poi>> fetchInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int maxResults = 20,
  }) async {
    final wikiPois = await _wikiService.fetchIntelligentPoisInBounds(
      north: north,
      south: south,
      east: east,
      west: west,
      maxResults: maxResults,
    );

    return wikiPois.map((wikiPoi) {
      return Poi(
        id: wikiPoi.title, // используем title как ID
        name: wikiPoi.title,
        lat: wikiPoi.lat,
        lon: wikiPoi.lon,
        description: wikiPoi.description ?? '',
        audio: '', // will be generated/added later
        interestScore: wikiPoi.interestScore,
        category: wikiPoi.category,
        interestLevel: wikiPoi.interestLevel,
      );
    }).toList();
  }

  /// Legacy method for backward compatibility
  Future<List<Poi>> fetchNearby(double lat, double lon, {int radius = 1000}) async {
    final wikiPois = await _wikiService.fetchNearbyWithDescriptions(lat, lon, radius: radius);

    return wikiPois.map((wikiPoi) {
      return Poi(
        id: wikiPoi.title, // используем title как ID
        name: wikiPoi.title,
        lat: wikiPoi.lat,
        lon: wikiPoi.lon,
        description: wikiPoi.description ?? '',
        audio: '', // will be generated/added later
        interestScore: wikiPoi.interestScore,
        category: wikiPoi.category,
        interestLevel: wikiPoi.interestLevel,
      );
    }).toList();
  }

  /// Clear caches
  void clearCaches() {
    _wikiService.clearCaches();
  }
}
