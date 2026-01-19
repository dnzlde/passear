// test/services/poi_cache/poi_cache_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/models/poi.dart';
import 'package:passear/models/settings.dart';
import 'package:passear/services/poi_cache/poi_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    // Mock path_provider plugin
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/test_app_documents';
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

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

      // Should wait for fetch and return empty (fetch returns empty)
      expect(result, isEmpty);

      // Should have triggered fetch
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

      // First call - should miss cache and fetch (4 tiles)
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

      // Should have fetched for all 4 tiles
      expect(fetchCallCount, equals(4));
      expect(result1, isNotEmpty);

      // Second call - should hit cache
      fetchCallCount = 0; // Reset counter
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
      expect(fetchCallCount, equals(0));
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

      // First call - cache miss (4 tiles)
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

      expect(fetchCallCount, equals(4));

      // Wait for TTL to expire
      await Future.delayed(Duration(milliseconds: 600));

      // Second call after TTL - should return stale data and refresh in background
      fetchCallCount = 0; // Reset
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

      // Should trigger refresh in background for 4 tiles
      // Since we have stale data, refresh happens in background (not awaited)
      await Future.delayed(Duration(milliseconds: 200));
      expect(fetchCallCount, equals(4));
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

      // First call should return deduplicated result
      expect(
        result.where((poi) => poi.id == 'duplicate-poi').length,
        equals(1),
      );

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

      // First call - cache miss (4 tiles)
      await freshCache.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async => [],
      );

      final stats1 = freshCache.getStats();
      expect(stats1['misses'], equals(4));

      // Second call - cache hit (4 tiles)
      await freshCache.getPoisForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        settings: settings,
        fetchFunction: (bounds) async => [],
      );

      final stats2 = freshCache.getStats();
      expect(stats2['hits'], equals(4));
      expect(stats2['misses'], equals(4));

      await freshCache.close();
    });
  });
}
