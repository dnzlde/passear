// lib/services/poi_service.dart
import '../models/poi.dart';
import '../models/settings.dart';
import 'wikipedia_poi_service.dart';
import 'overpass_poi_service.dart';
import 'api_client.dart';
import 'settings_service.dart';
import 'poi_cache/poi_cache_service.dart';
import 'poi_cache/tile_utils.dart';

class PoiService {
  WikipediaPoiService? _wikiService;
  OverpassPoiService? _overpassService;
  final SettingsService _settingsService = SettingsService.instance;
  final ApiClient? _apiClient;
  PoiProvider _currentProvider = PoiProvider.wikipedia;
  PoiCacheService? _cacheService;
  bool _cacheInitialized = false;

  PoiService({ApiClient? apiClient}) : _apiClient = apiClient;

  /// Initialize cache service if not already initialized
  Future<void> _ensureCacheInitialized() async {
    if (_cacheInitialized) return;
    _cacheService ??= PoiCacheService();
    await _cacheService!.initialize();
    _cacheInitialized = true;
  }

  /// Get or create the appropriate POI service based on current provider
  WikipediaPoiService _getWikiService() {
    _wikiService ??= WikipediaPoiService(apiClient: _apiClient);
    return _wikiService!;
  }

  /// Get or create the Overpass POI service
  OverpassPoiService _getOverpassService() {
    _overpassService ??= OverpassPoiService(apiClient: _apiClient);
    return _overpassService!;
  }

  /// Update the POI provider
  void updateProvider(PoiProvider provider) {
    _currentProvider = provider;
    // Clear cache when changing providers
    clearCaches();
  }

  /// Fetch POIs for a single tile (used by cache service)
  /// Fetches ALL POIs in the tile area, filtering is done at display time
  Future<List<Poi>> _fetchPoisForTile(GeoBounds bounds) async {
    // Load current settings
    final settings = await _settingsService.loadSettings();

    List<Poi> allPois;

    switch (_currentProvider) {
      case PoiProvider.wikipedia:
        final wikiPois = await _getWikiService().fetchIntelligentPoisInBounds(
          north: bounds.north,
          south: bounds.south,
          east: bounds.east,
          west: bounds.west,
          maxResults: 100, // Fetch more POIs per tile for comprehensive caching
        );
        allPois = wikiPois.map((wikiPoi) {
          return Poi(
            id: wikiPoi.title,
            name: wikiPoi.title,
            lat: wikiPoi.lat,
            lon: wikiPoi.lon,
            description: wikiPoi.description ?? '',
            imageUrl: wikiPoi.imageUrl,
            audio: '',
            interestScore: wikiPoi.interestScore,
            category: wikiPoi.category,
            interestLevel: wikiPoi.interestLevel,
            isDescriptionLoaded: wikiPoi.description != null,
          );
        }).toList();
        break;

      case PoiProvider.overpass:
        final overpassPois = await _getOverpassService().fetchPoisInBounds(
          north: bounds.north,
          south: bounds.south,
          east: bounds.east,
          west: bounds.west,
          maxResults: 100,
        );
        allPois = overpassPois;
        break;

      case PoiProvider.googlePlaces:
        allPois = [];
        break;
    }

    // Filter POIs based on enabled categories
    final filteredPois = allPois
        .where((poi) => settings.isCategoryEnabled(poi.category))
        .toList();

    return filteredPois;
  }

  /// Fetch POIs within rectangular bounds using intelligent scoring
  Future<List<Poi>> fetchInBounds({
    required double north,
    required double south,
    required double east,
    required double west,
    int? maxResults,
  }) async {
    // Initialize cache if needed
    await _ensureCacheInitialized();

    // Load current settings
    final settings = await _settingsService.loadSettings();
    final effectiveMaxResults = maxResults ?? settings.maxPoiCount;

    // Use cache service to get POIs
    final allPois = await _cacheService!.getPoisForViewport(
      north: north,
      south: south,
      east: east,
      west: west,
      settings: settings,
      fetchFunction: _fetchPoisForTile,
    );

    // Sort by interest score and return top results
    allPois.sort((a, b) => b.interestScore.compareTo(a.interestScore));
    return allPois.take(effectiveMaxResults).toList();
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
        imageUrl: wikiPoi.imageUrl,
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
      final imageUrl = await _getWikiService().fetchImageUrl(poi.name);

      if ((description != null && description.isNotEmpty) || imageUrl != null) {
        return poi.copyWith(
          description: description != null && description.isNotEmpty
              ? description
              : poi.description,
          imageUrl: imageUrl,
          isDescriptionLoaded:
              description != null && description.isNotEmpty
                  ? true
                  : poi.isDescriptionLoaded,
        );
      }
      // If description is null or empty, return original POI without marking as loaded
      return poi;
    } catch (e) {
      // If fetching fails, return the original POI
      return poi;
    }
  }

  /// Clear caches
  Future<void> clearCaches() async {
    _wikiService?.clearCaches();
    await _ensureCacheInitialized();
    await _cacheService?.clearCache();
  }

  /// Clear all empty cached tiles
  /// Useful for cleaning up incorrectly cached empty tiles from API errors
  /// Returns the number of tiles removed
  Future<int> clearEmptyTiles() async {
    await _ensureCacheInitialized();
    return await _cacheService?.clearEmptyTiles() ?? 0;
  }

  /// Get cache statistics
  Map<String, dynamic>? getCacheStats() {
    return _cacheService?.getStats();
  }
}
