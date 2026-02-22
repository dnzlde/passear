// test/services/poi_telemetry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_telemetry.dart';

void main() {
  group('PoiTelemetry', () {
    test('startTrace produces unique request IDs', () {
      final t1 = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      final t2 = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      expect(t1.requestId, isNotEmpty);
      expect(t2.requestId, isNotEmpty);
      expect(t1.requestId, isNot(equals(t2.requestId)));
    });

    test('same viewport bounds produce the same viewportHash', () {
      final t1 = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      final t2 = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      expect(t1.viewportHash, equals(t2.viewportHash));
    });

    test('different viewport bounds produce different hashes', () {
      final t1 = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      final t2 = PoiTelemetry.startTrace(
        north: 51.52,
        south: 51.50,
        east: -0.10,
        west: -0.12,
      );
      expect(t1.viewportHash, isNot(equals(t2.viewportHash)));
    });

    test('viewportHash does not expose raw coordinate strings', () {
      final trace = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      // Hash must not contain full float representations of the coordinates
      expect(trace.viewportHash, isNot(contains('32.08')));
      expect(trace.viewportHash, isNot(contains('34.80')));
    });

    test('viewportHash is 8 hex characters long', () {
      final trace = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
      expect(trace.viewportHash, hasLength(8));
      expect(
        trace.viewportHash,
        matches(RegExp(r'^[0-9a-f]{8}$')),
      );
    });
  });

  group('PoiRequestTrace', () {
    late PoiRequestTrace trace;

    setUp(() {
      trace = PoiTelemetry.startTrace(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );
    });

    test('initial counters are zero', () {
      expect(trace.cacheHits, equals(0));
      expect(trace.cacheMisses, equals(0));
      expect(trace.staleHits, equals(0));
      expect(trace.retries, equals(0));
      expect(trace.lastErrorClass, isNull);
    });

    test('recordCacheEvent increments hitFresh counter', () {
      trace.recordCacheEvent('tile:15:1:2:abc', PoiCacheResult.hitFresh);
      expect(trace.cacheHits, equals(1));
      expect(trace.cacheMisses, equals(0));
      expect(trace.staleHits, equals(0));
    });

    test('recordCacheEvent increments hitStale counter', () {
      trace.recordCacheEvent('tile:15:1:2:abc', PoiCacheResult.hitStale);
      expect(trace.staleHits, equals(1));
      expect(trace.cacheHits, equals(0));
      expect(trace.cacheMisses, equals(0));
    });

    test('recordCacheEvent increments miss counter', () {
      trace.recordCacheEvent('tile:15:1:2:abc', PoiCacheResult.miss);
      expect(trace.cacheMisses, equals(1));
      expect(trace.cacheHits, equals(0));
      expect(trace.staleHits, equals(0));
    });

    test('recordCacheEvent accumulates multiple events', () {
      trace.recordCacheEvent('t1', PoiCacheResult.hitFresh);
      trace.recordCacheEvent('t2', PoiCacheResult.hitFresh);
      trace.recordCacheEvent('t3', PoiCacheResult.miss);
      trace.recordCacheEvent('t4', PoiCacheResult.hitStale);

      expect(trace.cacheHits, equals(2));
      expect(trace.cacheMisses, equals(1));
      expect(trace.staleHits, equals(1));
    });

    test('recordFetchAttempt does not count attempt=1 as retry', () {
      trace.recordFetchAttempt(attempt: 1);
      expect(trace.retries, equals(0));
    });

    test('recordFetchAttempt counts attempt>1 as retry', () {
      trace.recordFetchAttempt(attempt: 1);
      trace.recordFetchAttempt(attempt: 2);
      trace.recordFetchAttempt(attempt: 3);
      expect(trace.retries, equals(2));
    });

    test('recordFetchAttempt stores the error class', () {
      trace.recordFetchAttempt(attempt: 1, errorClass: 'TimeoutException');
      expect(trace.lastErrorClass, equals('TimeoutException'));
    });

    test('recordFetchAttempt overwrites error class on subsequent calls', () {
      trace.recordFetchAttempt(attempt: 1, errorClass: 'TimeoutException');
      trace.recordFetchAttempt(attempt: 2, errorClass: 'SocketException');
      expect(trace.lastErrorClass, equals('SocketException'));
    });

    test('complete does not throw', () {
      expect(() => trace.complete(poiCount: 42), returnsNormally);
    });
  });
}
