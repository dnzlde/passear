// test/services/poi_cache/tile_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_cache/tile_utils.dart';

void main() {
  group('TileUtils', () {
    test('should convert lat/lon to tile coordinates', () {
      // Test case: Tel Aviv center at zoom 15
      // Tel Aviv is at approximately 32.0853° N, 34.7818° E
      final x = TileUtils.lonToTileX(34.7924, 15);
      final y = TileUtils.latToTileY(32.0741, 15);

      // Using Web Mercator projection
      expect(x, equals(19550));
      expect(y, equals(13298));
    });

    test('should convert tile coordinates back to bounds', () {
      // Test with the Tel Aviv tile
      final tile = TileCoordinate(x: 19550, y: 13298, z: 15);
      final bounds = TileUtils.tileToBounds(tile);

      // Verify bounds are reasonable (should contain Tel Aviv)
      expect(bounds.north, greaterThan(32.0));
      expect(bounds.south, lessThan(32.1));
      expect(bounds.east, greaterThan(34.7));
      expect(bounds.west, lessThan(34.8));

      // Verify north > south and east > west
      expect(bounds.north, greaterThan(bounds.south));
      expect(bounds.east, greaterThan(bounds.west));
    });

    test('should get tiles for viewport', () {
      // Test with a small viewport in Tel Aviv
      final tiles = TileUtils.getTilesForViewport(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        zoom: 15,
      );

      // Should get at least one tile
      expect(tiles, isNotEmpty);

      // All tiles should be at zoom 15
      for (final tile in tiles) {
        expect(tile.z, equals(15));
      }
    });

    test('should get multiple tiles for larger viewport', () {
      // Test with a larger viewport
      final tiles = TileUtils.getTilesForViewport(
        north: 32.1,
        south: 32.0,
        east: 34.85,
        west: 34.75,
        zoom: 15,
      );

      // Should get multiple tiles for this viewport size
      expect(tiles.length, greaterThan(1));

      // Check that tiles are unique
      final uniqueTiles = tiles.toSet();
      expect(uniqueTiles.length, equals(tiles.length));
    });

    test('should create consistent cache keys', () {
      final tile = TileCoordinate(x: 100, y: 200, z: 15);
      final hash = 'abc123';

      final key1 = TileUtils.createTileKey(tile, hash);
      final key2 = TileUtils.createTileKey(tile, hash);

      // Keys should be consistent
      expect(key1, equals(key2));
      expect(key1, equals('poi:15:100:200:abc123'));
    });

    test('should create different keys for different filters', () {
      final tile = TileCoordinate(x: 100, y: 200, z: 15);

      final key1 = TileUtils.createTileKey(tile, 'hash1');
      final key2 = TileUtils.createTileKey(tile, 'hash2');

      // Keys should be different with different filter hashes
      expect(key1, isNot(equals(key2)));
    });

    test('TileCoordinate equality should work correctly', () {
      final tile1 = TileCoordinate(x: 100, y: 200, z: 15);
      final tile2 = TileCoordinate(x: 100, y: 200, z: 15);
      final tile3 = TileCoordinate(x: 101, y: 200, z: 15);

      expect(tile1, equals(tile2));
      expect(tile1, isNot(equals(tile3)));
      expect(tile1.hashCode, equals(tile2.hashCode));
    });
  });
}
