# POI Cache Implementation Guide

## Overview

This document describes the tile-based POI caching system implemented to eliminate redundant network requests when users pan or zoom the map.

## Architecture

### Tile-Based Approach

The map is divided into tiles at zoom level 15 (~2.4km x 2.4km at the equator). Each tile independently caches its POIs with metadata for TTL (Time-To-Live) and LRU (Least Recently Used) eviction.

**Key Components:**

1. **TileUtils** (`lib/services/poi_cache/tile_utils.dart`)
   - Converts viewport bounds to tile coordinates
   - Converts tile coordinates back to geographic bounds
   - Uses Web Mercator projection for accurate mapping

2. **PoiCacheEntry** (`lib/services/poi_cache/poi_cache_entry.dart`)
   - Data model for cached tiles
   - Tracks: POIs, updatedAt, lastAccessedAt timestamps
   - Provides TTL validation and access tracking

3. **PoiTileStorage** (`lib/services/poi_cache/poi_tile_storage.dart`)
   - Hive-based persistent storage layer
   - JSON serialization for POIs
   - Safe box operations with race condition protection

4. **PoiCacheService** (`lib/services/poi_cache/poi_cache_service.dart`)
   - Main caching orchestration
   - Implements stale-while-revalidate pattern
   - Manages TTL, LRU eviction, and concurrency control

## Configuration

Default configuration in `PoiCacheConfig`:

```dart
PoiCacheConfig(
  ttl: Duration(hours: 12),      // Cache expires after 12 hours
  maxTiles: 500,                  // Maximum 500 tiles in cache
  maxConcurrentRequests: 4,       // Limit 4 concurrent network requests
)
```

## Cache Key Structure

Cache keys include filter parameters to prevent mixing different data:

```
poi:{zoom}:{x}:{y}:{filtersHash}
```

Where:
- `zoom`: Tile zoom level (15)
- `x`, `y`: Tile coordinates
- `filtersHash`: SHA-256 hash of filter settings (provider, categories, maxCount)

## Stale-While-Revalidate Pattern

The cache implements an intelligent refresh strategy:

1. **Cache Hit (Fresh)**: Return cached data immediately, update lastAccess
2. **Cache Hit (Stale)**: Return cached data immediately, refresh in background
3. **Cache Miss (No Data)**: Wait for network fetch, then return

This ensures:
- Instant response for users (no loading delays)
- Always up-to-date data (background refresh)
- Offline capability (stale data better than no data)

## POI Deduplication

POIs may appear in multiple adjacent tiles. The cache deduplicates by POI ID:

```dart
final allPois = <String, Poi>{}; // Map by ID
for (final poi in cachedEntry.pois) {
  allPois[poi.id] = poi; // Automatically deduplicates
}
```

## LRU Eviction

When cache exceeds `maxTiles`, the service:

1. Sorts tiles by `lastAccessedAt` (oldest first)
2. Removes oldest tiles until under limit
3. Runs after background tile fetches

## Performance Characteristics

### Cache Hit Rate

Monitor via `getCacheStats()`:

```dart
final stats = poiService.getCacheStats();
// {
//   'hits': 120,
//   'misses': 30, 
//   'stale': 15,
//   'hitRate': 0.80,  // 80% hit rate
//   'total': 150
// }
```

### Network Requests

**Before Caching:**
- Pan/zoom: 1 request every time
- Visit same area 3 times: 3 requests

**After Caching:**
- Pan/zoom (first time): 1-4 requests (based on viewport size)
- Pan/zoom (cached): 0 requests
- Visit same area 3 times: 1 request (cached for next 2 visits)

### Storage

- Each tile: ~5-50 KB (depends on POI count)
- 500 tiles max: ~2.5-25 MB total
- Persists across app restarts

## Testing

### Unit Tests

**TileUtils Tests** (7 tests):
- Lat/lon to tile coordinate conversion
- Tile to bounds conversion
- Viewport to tiles calculation
- Cache key generation
- Coordinate equality

**Cache Service Tests** (7 tests):
- Filter hash consistency
- Cache miss behavior
- Cache hit behavior (fresh)
- Stale-while-revalidate pattern
- POI deduplication
- Statistics tracking
- TTL expiration

Run tests:
```bash
flutter test test/services/poi_cache/
```

### Integration Testing

The cache is automatically tested via existing POI service tests:

```bash
flutter test test/services/poi_service_test.dart
```

## Usage Example

```dart
// Initialize service (done automatically in PoiService)
final cache = PoiCacheService();
await cache.initialize();

// Fetch POIs for viewport
final pois = await cache.getPoisForViewport(
  north: 32.08,
  south: 32.07,
  east: 34.80,
  west: 34.79,
  settings: appSettings,
  fetchFunction: (bounds) async {
    // Your API call here
    return await apiClient.fetchPois(bounds);
  },
);

// Get statistics
final stats = cache.getStats();
print('Cache hit rate: ${stats['hitRate']}');

// Clear cache
await cache.clearCache();
```

## Debugging

Enable debug logging in `poi_cache_service.dart`:

```dart
debugPrint('POI Cache: Processing ${tiles.length} tiles');
debugPrint('POI Cache: HIT (fresh) - $cacheKey');
debugPrint('POI Cache: MISS - $cacheKey');
```

Monitor logs for:
- Cache hit/miss patterns
- Tile coverage for viewports
- Background refresh operations
- LRU eviction events

## Future Enhancements

Potential improvements:

1. **Variable Zoom Levels**: Cache at multiple zoom levels for better coverage
2. **Predictive Prefetch**: Pre-load adjacent tiles based on pan direction
3. **Compression**: Compress cached data to reduce storage usage
4. **Partial Updates**: Update individual POIs without refetching entire tile
5. **Network Optimization**: Batch multiple tile requests into single API call
6. **Cache Warmup**: Pre-populate cache for popular areas

## Troubleshooting

### Cache Not Working

1. Check initialization: `await cache.initialize()`
2. Verify Hive permissions (mobile)
3. Check TTL settings (default: 12 hours)
4. Review filter hash consistency

### High Memory Usage

1. Reduce `maxTiles` in config
2. Decrease TTL to expire tiles faster
3. Call `clearCache()` periodically

### Stale Data Issues

1. Reduce TTL for more frequent updates
2. Call `clearCache()` when changing providers
3. Monitor background refresh logs

## References

- Web Mercator Projection: https://en.wikipedia.org/wiki/Web_Mercator_projection
- Tile Map Service: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
- Hive Database: https://docs.hivedb.dev/
- Stale-While-Revalidate: https://web.dev/stale-while-revalidate/
