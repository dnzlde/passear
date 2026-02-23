// test/services/viewport_request_coalescer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/viewport_request_coalescer.dart';

void main() {
  group('ViewportRequestCoalescer.buildKey', () {
    test('normalises bounds to 4 decimal places', () {
      final key = ViewportRequestCoalescer.buildKey(
        north: 32.07412345,
        south: 32.07000001,
        east: 34.79999999,
        west: 34.78512345,
        filtersHash: '',
      );
      // 32.07412345 → 32.0741, 32.07000001 → 32.0700,
      // 34.79999999 → 34.8000, 34.78512345 → 34.7851
      expect(key, equals('32.0741:32.0700:34.8000:34.7851:'));
    });

    test('includes filtersHash in the key', () {
      final base = {
        'north': 32.0741,
        'south': 32.0700,
        'east': 34.8000,
        'west': 34.7851,
      };
      final key1 = ViewportRequestCoalescer.buildKey(
        north: base['north']!,
        south: base['south']!,
        east: base['east']!,
        west: base['west']!,
        filtersHash: 'wikipedia',
      );
      final key2 = ViewportRequestCoalescer.buildKey(
        north: base['north']!,
        south: base['south']!,
        east: base['east']!,
        west: base['west']!,
        filtersHash: 'overpass',
      );
      expect(key1, isNot(equals(key2)));
    });

    test('different bounds produce different keys', () {
      final key1 = ViewportRequestCoalescer.buildKey(
        north: 32.0741,
        south: 32.0700,
        east: 34.8000,
        west: 34.7851,
      );
      final key2 = ViewportRequestCoalescer.buildKey(
        north: 32.1000,
        south: 32.0700,
        east: 34.8000,
        west: 34.7851,
      );
      expect(key1, isNot(equals(key2)));
    });

    test('coordinates within 4-decimal rounding map to same key', () {
      // 32.07411 and 32.07414 both truncate/round to 32.0741
      final key1 = ViewportRequestCoalescer.buildKey(
        north: 32.07411,
        south: 32.07000,
        east: 34.80000,
        west: 34.78510,
      );
      final key2 = ViewportRequestCoalescer.buildKey(
        north: 32.07414,
        south: 32.07000,
        east: 34.80000,
        west: 34.78510,
      );
      expect(key1, equals(key2));
    });
  });

  group('ViewportRequestCoalescer state', () {
    test('shouldCoalesce returns false when no request is in-flight', () {
      final coalescer = ViewportRequestCoalescer();
      expect(coalescer.shouldCoalesce('some:key'), isFalse);
    });

    test('shouldCoalesce returns true for same key after beginRequest', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      expect(coalescer.shouldCoalesce('k1'), isTrue);
    });

    test('shouldCoalesce returns false for different key while in-flight', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      expect(coalescer.shouldCoalesce('k2'), isFalse);
    });

    test('shouldCoalesce returns false after endRequest', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      coalescer.endRequest('k1');
      expect(coalescer.shouldCoalesce('k1'), isFalse);
    });

    test('endRequest is a no-op when key does not match in-flight', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      coalescer.endRequest('k2'); // different key — should not clear k1
      expect(coalescer.shouldCoalesce('k1'), isTrue);
    });

    test('reset clears in-flight state', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      coalescer.reset();
      expect(coalescer.shouldCoalesce('k1'), isFalse);
    });

    test('new request can begin after previous request ends', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      coalescer.endRequest('k1');
      coalescer.beginRequest('k2');
      expect(coalescer.shouldCoalesce('k2'), isTrue);
      expect(coalescer.shouldCoalesce('k1'), isFalse);
    });

    test('new request after reset is not coalesced with old key', () {
      final coalescer = ViewportRequestCoalescer();
      coalescer.beginRequest('k1');
      coalescer.reset();
      coalescer.beginRequest('k2');
      expect(coalescer.shouldCoalesce('k2'), isTrue);
      expect(coalescer.shouldCoalesce('k1'), isFalse);
    });
  });
}
