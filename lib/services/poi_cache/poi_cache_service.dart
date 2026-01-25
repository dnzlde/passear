// lib/services/poi_cache/poi_cache_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../models/poi.dart';
import '../../models/settings.dart';
import 'poi_cache_entry.dart';
import 'poi_tile_storage.dart';
import 'tile_utils.dart';

/// Configuration for POI cache
class PoiCacheConfig {
  /// Time-to-live for cached tiles (default: 12 hours)
  final Duration ttl;

  /// Maximum number of tiles to keep in cache (LRU eviction)
  final int maxTiles;

  /// Maximum concurrent network requests
  final int maxConcurrentRequests;

  const PoiCacheConfig({
    this.ttl = const Duration(hours: 12),
    this.maxTiles = 500,
    this.maxConcurrentRequests = 4,
  });
}

/// Service for managing tile-based POI caching
class PoiCacheService {
  final PoiTileStorage _storage = PoiTileStorage();
  final PoiCacheConfig config;

  // Metrics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _staleHits = 0;

  // Semaphore for limiting concurrent requests
  final Map<String, Completer<void>> _inflightRequests = {};

  // Track background refresh operations
  final List<Future<void>> _backgroundOperations = [];

  PoiCacheService({this.config = const PoiCacheConfig()});

  /// Initialize the cache service
  Future<void> initialize() async {
    await _storage.initialize();
  }

  /// Create a hash of filter parameters for cache key
  /// Note: maxPoiCount is NOT included - we cache all POIs and filter on display
  String createFiltersHash(AppSettings settings) {
    final filterData = {
      'provider': settings.poiProvider.name,
      'categories': settings.enabledCategories.entries
          .where((e) => e.value)
          .map((e) => e.key.name)
          .toList()
        ..sort(),
      // maxCount deliberately excluded - cache all POIs, filter at display time
    };
    final jsonString = jsonEncode(filterData);
    final bytes = utf8.encode(jsonString);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16); // Use first 16 chars
  }

  /// Get POIs for a viewport with caching
  /// Returns cached POIs immediately if available (even if stale),
  /// and triggers background refresh for stale entries
  Future<List<Poi>> getPoisForViewport({
    required double north,
    required double south,
    required double east,
    required double west,
    required AppSettings settings,
    required Future<List<Poi>> Function(GeoBounds bounds) fetchFunction,
  }) async {
    final filtersHash = createFiltersHash(settings);
    final tiles = TileUtils.getTilesForViewport(
      north: north,
      south: south,
      east: east,
      west: west,
    );

    debugPrint('POI Cache: Processing ${tiles.length} tiles for viewport');

    final allPois = <String, Poi>{}; // Use map to deduplicate by ID
    final tilesToFetch = <TileCoordinate>[];

    // Check cache for each tile
    for (final tile in tiles) {
      final cacheKey = TileUtils.createTileKey(tile, filtersHash);
      final cachedEntry = await _storage.get(cacheKey);

      if (cachedEntry != null) {
        if (cachedEntry.isValid(config.ttl)) {
          // Fresh cache hit
          _cacheHits++;
          debugPrint('POI Cache: HIT (fresh) - $cacheKey');

          // Update last access time
          await _storage.put(cacheKey, cachedEntry.copyWithAccess());

          // Add POIs to result
          for (final poi in cachedEntry.pois) {
            allPois[poi.id] = poi;
          }
        } else {
          // Stale cache hit - use it but schedule refresh
          _staleHits++;
          debugPrint('POI Cache: HIT (stale) - $cacheKey');

          // Add stale POIs to result
          for (final poi in cachedEntry.pois) {
            allPois[poi.id] = poi;
          }

          // Schedule background refresh
          tilesToFetch.add(tile);
        }
      } else {
        // Cache miss
        _cacheMisses++;
        debugPrint('POI Cache: MISS - $cacheKey');
        tilesToFetch.add(tile);
      }
    }

    // Fetch missing/stale tiles
    if (tilesToFetch.isNotEmpty) {
      // If we have no cached data at all, wait for fetches to complete
      // Otherwise fetch in background for better UX (stale-while-revalidate)
      if (allPois.isEmpty) {
        await _fetchTilesInBackground(
          tiles: tilesToFetch,
          filtersHash: filtersHash,
          fetchFunction: fetchFunction,
        );

        // After fetching, collect the newly cached POIs
        for (final tile in tilesToFetch) {
          final cacheKey = TileUtils.createTileKey(tile, filtersHash);
          final cachedEntry = await _storage.get(cacheKey);
          if (cachedEntry != null) {
            for (final poi in cachedEntry.pois) {
              allPois[poi.id] = poi;
            }
          }
        }
      } else {
        // Have some data, fetch updates in background
        final backgroundOp = _fetchTilesInBackground(
          tiles: tilesToFetch,
          filtersHash: filtersHash,
          fetchFunction: fetchFunction,
        );
        _backgroundOperations.add(backgroundOp);
        // Clean up completed operations
        backgroundOp.then((_) => _backgroundOperations.remove(backgroundOp));
      }
    }

    // Log cache metrics periodically
    final totalRequests = _cacheHits + _cacheMisses;
    if (totalRequests % 10 == 0 && totalRequests > 0) {
      final hitRate = (_cacheHits / totalRequests * 100).toStringAsFixed(1);
      debugPrint(
        'POI Cache Stats: Hits=$_cacheHits, Misses=$_cacheMisses, Stale=$_staleHits, Hit Rate=$hitRate%',
      );
    }

    return allPois.values.toList();
  }

  /// Fetch tiles in background with concurrency control
  Future<void> _fetchTilesInBackground({
    required List<TileCoordinate> tiles,
    required String filtersHash,
    required Future<List<Poi>> Function(GeoBounds bounds) fetchFunction,
  }) async {
    // Limit concurrent fetches
    final futures = <Future<void>>[];

    for (final tile in tiles) {
      final cacheKey = TileUtils.createTileKey(tile, filtersHash);

      // Check if already fetching this tile
      if (_inflightRequests.containsKey(cacheKey)) {
        await _inflightRequests[cacheKey]!.future;
        continue;
      }

      // Create a completer for this request
      final completer = Completer<void>();
      _inflightRequests[cacheKey] = completer;

      final future = _fetchAndCacheTile(
        tile: tile,
        cacheKey: cacheKey,
        fetchFunction: fetchFunction,
      ).then((_) {
        _inflightRequests.remove(cacheKey);
        completer.complete();
      }).catchError((error) {
        _inflightRequests.remove(cacheKey);
        completer.completeError(error);
        debugPrint('POI Cache: Error fetching tile $cacheKey: $error');
      });

      futures.add(future);

      // Limit concurrent requests
      if (futures.length >= config.maxConcurrentRequests) {
        await Future.any(futures);
        // Clear all futures from the list after any one completes.
        // This is intentional: we use _inflightRequests map as the real
        // semaphore to prevent duplicate fetches, and futures list is only
        // for concurrency limiting. All futures will complete in background.
        futures.clear();
      }
    }

    // Wait for all fetches to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    // Perform LRU eviction if needed
    await _performLruEviction();
  }

  /// Fetch and cache a single tile
  Future<void> _fetchAndCacheTile({
    required TileCoordinate tile,
    required String cacheKey,
    required Future<List<Poi>> Function(GeoBounds bounds) fetchFunction,
  }) async {
    final bounds = TileUtils.tileToBounds(tile);

    debugPrint('POI Cache: Fetching tile $cacheKey');

    final pois = await fetchFunction(bounds);

    // Cache the result even if empty - if fetchFunction succeeds (no exception),
    // it means we got a successful HTTP 200 response with legitimately no POIs
    // HTTP errors will throw exceptions and won't reach this point
    final entry = PoiCacheEntry(
      pois: pois,
      updatedAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
    );

    await _storage.put(cacheKey, entry);
    debugPrint('POI Cache: Cached ${pois.length} POIs for $cacheKey');
  }

  /// Perform LRU eviction if cache exceeds max size
  Future<void> _performLruEviction() async {
    final size = await _storage.getSize();
    if (size <= config.maxTiles) return;

    debugPrint(
      'POI Cache: Performing LRU eviction (size=$size, max=${config.maxTiles})',
    );

    // Get all entries with their last access times
    final keys = await _storage.getAllKeys();
    final entries = <String, DateTime>{};

    for (final key in keys) {
      final entry = await _storage.get(key);
      if (entry != null) {
        entries[key] = entry.lastAccessedAt;
      }
    }

    // Sort by last access time (oldest first)
    final sortedKeys = entries.keys.toList()
      ..sort((a, b) => entries[a]!.compareTo(entries[b]!));

    // Remove oldest entries until we're under the limit
    final toRemove = size - config.maxTiles;
    for (int i = 0; i < toRemove && i < sortedKeys.length; i++) {
      await _storage.delete(sortedKeys[i]);
      debugPrint('POI Cache: Evicted ${sortedKeys[i]}');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _storage.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    _staleHits = 0;
    debugPrint('POI Cache: Cleared all cache');
  }

  /// Clear all empty cached tiles (tiles with no POIs)
  /// Useful to force refresh of areas that may have new POIs now
  /// Note: Empty tiles are now legitimately cached (successful HTTP 200 with no POIs)
  Future<int> clearEmptyTiles() async {
    final keys = await _storage.getAllKeys();
    int removedCount = 0;

    for (final key in keys) {
      final entry = await _storage.get(key);
      if (entry != null && entry.pois.isEmpty) {
        await _storage.delete(key);
        removedCount++;
        debugPrint('POI Cache: Removed empty tile $key');
      }
    }

    debugPrint('POI Cache: Cleared $removedCount empty tiles');
    return removedCount;
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'stale': _staleHits,
      'hitRate': hitRate,
      'total': totalRequests,
    };
  }

  /// Close the service (cleanup)
  Future<void> close() async {
    // Wait for all inflight requests to complete
    // The while loop handles any new requests added during cleanup
    while (_inflightRequests.isNotEmpty) {
      final completers = _inflightRequests.values.toList();
      _inflightRequests.clear();
      await Future.wait(
        completers.map((c) => c.future.catchError((_) => null)),
      );
    }

    // Wait for all background operations to complete
    if (_backgroundOperations.isNotEmpty) {
      await Future.wait(
        _backgroundOperations.map((op) => op.catchError((_) => null)),
      );
      _backgroundOperations.clear();
    }

    await _storage.close();
  }
}
