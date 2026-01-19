// test/services/poi_cache/poi_cache_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/models/poi.dart';
import 'package:passear/models/settings.dart';
import 'package:passear/services/poi_cache/poi_cache_service.dart';
import 'package:passear/services/poi_cache/tile_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PoiCacheService', () {
    late PoiCacheService cacheService;

    setUp(() async {
      // Use short TTL for testing
      cacheService = PoiCacheService(
        config: PoiCacheConfig(
          ttl: Duration(milliseconds: 500),
          maxTiles: 10,
          maxConcurrentRequests: 2,
        ),
      );
      await cacheService.initialize();
      await cacheService.clearCache();
    });

    tearDown(() async {
      await cacheService.clearCache();
      await cacheService.close();
    });

    test('should create consistent filter hashes', () {
      final settings1 = AppSettings(
        poiProvider: PoiProvider.wikipedia,
        maxPoiCount: 20,
      );
      final settings2 = AppSettings(
        poiProvider: PoiProvider.wikipedia,
        maxPoiCount: 20,
      );

      final hash1 = cacheService.createFiltersHash(settings1);
      final hash2 = cacheService.createFiltersHash(settings2);

      expect(hash1, equals(hash2));
    });

    test('should create different filter hashes for different settings', () {
      final settings1 = AppSettings(
        poiProvider: PoiProvider.wikipedia,
        maxPoiCount: 20,
      );
      final settings2 = AppSettings(
        poiProvider: PoiProvider.overpass,
        maxPoiCount: 20,
      );

      final hash1 = cacheService.createFiltersHash(settings1);
      final hash2 = cacheService.createFiltersHash(settings2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('should return empty list for viewport with no cached data', () async {
      final settings = AppSettings();
      int fetchCallCount = 0;

      final result = await cacheService.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async {
          fetchCallCount++;
          return [];
        },
      );

      // Should return empty immediately (cache miss)
      expect(result, isEmpty);

      // Should trigger background fetch
      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCallCount, greaterThan(0));
    });

    test('should cache and retrieve POIs', () async {
      final settings = AppSettings();
      final testPois = [
        Poi(
          id: 'test-1',
          name: 'Test POI 1',
          lat: 32.075,
          lon: 34.795,
          description: 'Test',
          audio: '',
        ),
      ];

      int fetchCallCount = 0;

      // First call - should miss cache and fetch
      final result1 = await cacheService.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async {
          fetchCallCount++;
          return testPois;
        },
      );

      // Wait for background fetch to complete
      await Future.delayed(Duration(milliseconds: 200));

      // Second call - should hit cache
      final result2 = await cacheService.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async {
          fetchCallCount++;
          return testPois;
        },
      );

      // Should have cached POIs from first fetch
      expect(result2, isNotEmpty);
      expect(result2[0].id, equals('test-1'));

      // Should not fetch again (cache hit)
      expect(fetchCallCount, equals(1));
    });

    test('should refresh stale cache entries', () async {
      final settings = AppSettings();
      final testPois = [
        Poi(
          id: 'test-1',
          name: 'Test POI 1',
          lat: 32.075,
          lon: 34.795,
          description: 'Test',
          audio: '',
        ),
      ];

      int fetchCallCount = 0;

      // First call - cache miss
      await cacheService.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async {
          fetchCallCount++;
          return testPois;
        },
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Wait for TTL to expire
      await Future.delayed(Duration(milliseconds: 400));

      // Second call after TTL - should return stale data and refresh
      final result2 = await cacheService.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async {
          fetchCallCount++;
          return testPois;
        },
      );

      // Should return stale data immediately
      expect(result2, isNotEmpty);

      // Should trigger refresh in background
      await Future.delayed(Duration(milliseconds: 200));
      expect(fetchCallCount, equals(2));
    });

    test('should deduplicate POIs from multiple tiles', () async {
      final settings = AppSettings();
      final testPoi = Poi(
        id: 'duplicate-poi',
        name: 'Duplicate POI',
        lat: 32.075,
        lon: 34.795,
        description: 'Test',
        audio: '',
      );

      // Fetch function returns same POI for every tile
      final result = await cacheService.getPoisForViewport(
        north: 32.1,
        south: 32.0,
        east: 34.85,
        west: 34.75,
        settings: settings,
        fetchFunction: (bounds) async {
          return [testPoi];
        },
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Fetch again to get cached results
      final result2 = await cacheService.getPoisForViewport(
        north: 32.1,
        south: 32.0,
        east: 34.85,
        west: 34.75,
        settings: settings,
        fetchFunction: (bounds) async {
          return [testPoi];
        },
      );

      // Should only have one instance despite multiple tiles
      expect(
        result2.where((poi) => poi.id == 'duplicate-poi').length,
        equals(1),
      );
    });

    test('should track cache statistics', () async {
      final settings = AppSettings();
      await cacheService.clearCache(); // Reset stats

      // Create fresh service with reset stats
      final freshCache = PoiCacheService(
        config: PoiCacheConfig(ttl: Duration(hours: 1)),
      );
      await freshCache.initialize();
      await freshCache.clearCache();

      // First call - cache miss
      await freshCache.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async => [],
      );

      await Future.delayed(Duration(milliseconds: 100));

      final stats1 = freshCache.getStats();
      expect(stats1['misses'], greaterThan(0));

      // Second call - cache hit
      await freshCache.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async => [],
      );

      final stats2 = freshCache.getStats();
      expect(stats2['hits'], greaterThan(stats1['hits'] as int));

      await freshCache.close();
    });
  });
}
