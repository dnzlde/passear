// lib/services/poi_service.dart
import '../models/poi.dart';
import '../models/settings.dart';
import 'wikipedia_poi_service.dart';
import 'api_client.dart';
import 'settings_service.dart';

class PoiService {
  WikipediaPoiService? _wikiService;
  final SettingsService _settingsService = SettingsService.instance;
  final ApiClient? _apiClient;
  PoiProvider _currentProvider = PoiProvider.wikipedia;

  PoiService({ApiClient? apiClient}) : _apiClient = apiClient;

  /// Get or create the appropriate POI service based on current provider
  WikipediaPoiService _getWikiService() {
    _wikiService ??= WikipediaPoiService(apiClient: _apiClient);
    return _wikiService!;
  }

  /// Update the POI provider
  void updateProvider(PoiProvider provider) {
    _currentProvider = provider;
    // Clear cache when changing providers
    clearCaches();
  }

  /// Fetch POIs within rectangular bounds using intelligent scoring
  Future<List<Poi>> fetchInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int? maxResults,
  }) async {
    // Load current settings
    final settings = await _settingsService.loadSettings();
    final effectiveMaxResults = maxResults ?? settings.maxPoiCount;

    List<Poi> allPois;

    switch (_currentProvider) {
      case PoiProvider.wikipedia:
        final wikiPois = await _getWikiService().fetchIntelligentPoisInBounds(
          north: north,
          south: south,
          east: east,
          west: west,
          maxResults:
              effectiveMaxResults * 2, // Fetch more to allow for filtering
        );
        allPois = wikiPois.map((wikiPoi) {
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
            isDescriptionLoaded: wikiPoi.description != null,
          );
        }).toList();
        break;

      case PoiProvider.overpass:
        // TODO: Implement Overpass API (OpenStreetMap POIs)
        // For now, fall back to Wikipedia
        allPois = [];
        break;

      case PoiProvider.googlePlaces:
        // TODO: Implement Google Places API
        // For now, fall back to Wikipedia
        allPois = [];
        break;
    }

    // Filter POIs based on enabled categories
    final filteredPois = allPois
        .where((poi) => settings.isCategoryEnabled(poi.category))
        .toList();

    // Return only the requested number of POIs
    return filteredPois.take(effectiveMaxResults).toList();
  }

  /// Legacy method for backward compatibility
  Future<List<Poi>> fetchNearby(
    double lat,
    double lon, {
    int radius = 1000,
  }) async {
    final wikiPois = await _getWikiService().fetchNearbyWithDescriptions(
      lat,
      lon,
      radius: radius,
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
        isDescriptionLoaded: wikiPoi.description != null,
      );
    }).toList();
  }

  /// Fetch description for a specific POI on-demand
  Future<Poi> fetchPoiDescription(Poi poi) async {
    if (poi.isDescriptionLoaded) {
      return poi; // Description already loaded
    }

    try {
      final description = await _getWikiService().fetchDescription(poi.name);
      if (description != null && description.isNotEmpty) {
        return poi.copyWithDescription(description);
      }
      // If description is null or empty, return original POI without marking as loaded
      return poi;
    } catch (e) {
      // If fetching fails, return the original POI
      return poi;
    }
  }

  /// Clear caches
  void clearCaches() {
    _wikiService?.clearCaches();
  }
}
