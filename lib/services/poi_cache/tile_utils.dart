// lib/services/poi_cache/tile_utils.dart
import 'dart:math' as math;

/// Tile coordinate representing a specific map tile at a given zoom level
class TileCoordinate {
  final int x;
  final int y;
  final int z;

  const TileCoordinate({required this.x, required this.y, required this.z});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;

  @override
  String toString() => 'TileCoordinate(z:$z, x:$x, y:$y)';
}

/// Bounding box in geographic coordinates
class GeoBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const GeoBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

/// Utility class for tile-based operations
class TileUtils {
  /// Default zoom level for caching tiles (adjust based on your needs)
  /// Zoom 15 is a good balance: ~2.4km x 2.4km per tile at equator
  static const int defaultCacheZoom = 15;

  /// Convert latitude to tile Y coordinate at given zoom level
  static int latToTileY(double lat, int zoom) {
    final latRad = lat * math.pi / 180.0;
    final n = math.pow(2.0, zoom).toDouble();
    final tileY =
        (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n;
    return tileY.floor();
  }

  /// Convert longitude to tile X coordinate at given zoom level
  static int lonToTileX(double lon, int zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    final tileX = ((lon + 180.0) / 360.0) * n;
    return tileX.floor();
  }

  /// Calculate sinh(x) since it's not in dart:math
  static double sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2.0;
  }

  /// Convert tile coordinate to geographic bounds
  static GeoBounds tileToBounds(TileCoordinate tile) {
    final n = math.pow(2.0, tile.z).toDouble();

    final west = tile.x / n * 360.0 - 180.0;
    final east = (tile.x + 1) / n * 360.0 - 180.0;

    final northRad = math.atan(sinh(math.pi * (1 - 2 * tile.y / n)));
    final north = northRad * 180.0 / math.pi;

    final southRad = math.atan(sinh(math.pi * (1 - 2 * (tile.y + 1) / n)));
    final south = southRad * 180.0 / math.pi;

    return GeoBounds(north: north, south: south, east: east, west: west);
  }

  /// Get all tiles that cover the given viewport bounds
  static List<TileCoordinate> getTilesForViewport({
    required double north,
    required double south,
    required double east,
    required double west,
    int? zoom,
  }) {
    final effectiveZoom = zoom ?? defaultCacheZoom;

    // Convert corners to tile coordinates
    final minTileX = lonToTileX(west, effectiveZoom);
    final maxTileX = lonToTileX(east, effectiveZoom);
    final minTileY = latToTileY(north, effectiveZoom); // North has smaller Y
    final maxTileY = latToTileY(south, effectiveZoom); // South has larger Y

    final tiles = <TileCoordinate>[];

    // Handle wraparound at 180/-180 degrees longitude
    if (minTileX <= maxTileX) {
      // Normal case: no wraparound
      for (int x = minTileX; x <= maxTileX; x++) {
        for (int y = minTileY; y <= maxTileY; y++) {
          tiles.add(TileCoordinate(x: x, y: y, z: effectiveZoom));
        }
      }
    } else {
      // Wraparound case: viewport crosses 180/-180 meridian
      final maxTileAtZoom = math.pow(2, effectiveZoom).toInt() - 1;
      for (int x = minTileX; x <= maxTileAtZoom; x++) {
        for (int y = minTileY; y <= maxTileY; y++) {
          tiles.add(TileCoordinate(x: x, y: y, z: effectiveZoom));
        }
      }
      for (int x = 0; x <= maxTileX; x++) {
        for (int y = minTileY; y <= maxTileY; y++) {
          tiles.add(TileCoordinate(x: x, y: y, z: effectiveZoom));
        }
      }
    }

    return tiles;
  }

  /// Create a cache key for a tile with filter parameters
  static String createTileKey(TileCoordinate tile, String filtersHash) {
    return 'poi:${tile.z}:${tile.x}:${tile.y}:$filtersHash';
  }
}
