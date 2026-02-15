import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passear/map/map_page.dart';

void main() {
  group('POI load control', () {
    test('uses minimum threshold for small viewports', () {
      expect(calculatePoiMovementThresholdMeters(100), 50.0);
    });

    test('uses ratio threshold for larger viewports', () {
      expect(calculatePoiMovementThresholdMeters(400), 100.0);
    });

    test('loads on initial request regardless of movement', () {
      final shouldLoad = shouldLoadPoisForMovement(
        isInitialLoad: true,
        lastPoiRequestCenter: const LatLng(32.0, 34.0),
        currentCenter: const LatLng(32.0, 34.0),
        movementThresholdMeters: 100,
      );

      expect(shouldLoad, isTrue);
    });

    test('skips reload when movement is below threshold', () {
      final shouldLoad = shouldLoadPoisForMovement(
        isInitialLoad: false,
        lastPoiRequestCenter: const LatLng(32.0, 34.0),
        currentCenter: const LatLng(32.0001, 34.0001),
        movementThresholdMeters: 200,
      );

      expect(shouldLoad, isFalse);
    });
  });
}
