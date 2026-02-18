import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/services/overpass_poi_service.dart';

class _SequentialApiClient implements ApiClient {
  final List<Object> _responses;
  int callCount = 0;

  _SequentialApiClient(this._responses);

  @override
  Future<String> get(Uri url) async {
    if (callCount >= _responses.length) {
      throw Exception('No configured response for call #$callCount');
    }
    final response = _responses[callCount];
    callCount++;
    if (response is Exception) throw response;
    return response as String;
  }

  @override
  Future<String> post(Uri url, String body) {
    throw UnimplementedError();
  }
}

/// A fixed [Random] that always returns a predetermined value for [nextDouble].
class _FixedRandom implements Random {
  final double _doubleValue;
  _FixedRandom(this._doubleValue);

  @override
  double nextDouble() => _doubleValue;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  group('OverpassPoiService', () {
    test('retries on HTTP 429 and succeeds', () async {
      final apiClient = _SequentialApiClient([
        Exception('HTTP 429: Failed to fetch'),
        '{"elements":[]}',
      ]);
      final service = OverpassPoiService(
        apiClient: apiClient,
        random: _FixedRandom(0.0),
      );

      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );

      expect(pois, isEmpty);
      expect(apiClient.callCount, equals(2));
    });

    test('retries on timeout and succeeds', () async {
      final apiClient = _SequentialApiClient([
        TimeoutException('Overpass timed out'),
        '{"elements":[]}',
      ]);
      final service = OverpassPoiService(
        apiClient: apiClient,
        random: _FixedRandom(0.0),
      );

      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );

      expect(pois, isEmpty);
      expect(apiClient.callCount, equals(2));
    });

    test('retries on HTTP 5xx errors', () async {
      final apiClient = _SequentialApiClient([
        Exception('HTTP 500: Internal Server Error'),
        Exception('HTTP 502: Bad Gateway'),
        '{"elements":[]}',
      ]);
      final service = OverpassPoiService(
        apiClient: apiClient,
        random: _FixedRandom(0.0),
      );

      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );

      expect(pois, isEmpty);
      expect(apiClient.callCount, equals(3));
    });

    test('throws immediately on non-retryable error', () async {
      final apiClient = _SequentialApiClient([
        Exception('HTTP 400: Bad Request'),
      ]);
      final service = OverpassPoiService(
        apiClient: apiClient,
        random: _FixedRandom(0.0),
      );

      expect(
        () => service.fetchPoisInBounds(
          north: 32.08,
          south: 32.07,
          east: 34.80,
          west: 34.79,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('gives up after max attempts', () async {
      final apiClient = _SequentialApiClient([
        Exception('HTTP 429: Too Many Requests'),
        Exception('HTTP 429: Too Many Requests'),
        Exception('HTTP 429: Too Many Requests'),
      ]);
      final service = OverpassPoiService(
        apiClient: apiClient,
        random: _FixedRandom(0.0),
      );

      expect(
        () => service.fetchPoisInBounds(
          north: 32.08,
          south: 32.07,
          east: 34.80,
          west: 34.79,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('OverpassPoiService retry delay', () {
    test('uses exponential backoff', () {
      // With jitter factor = 1.0 (random returns 1.0, so 0.5 + 0.5*1.0 = 1.0)
      final service = OverpassPoiService(
        random: _FixedRandom(1.0),
      );

      // attempt 1: baseDelay * 2^0 = 1000ms * 1.0 jitter = 1000ms
      expect(service.calculateDelay(1), equals(Duration(milliseconds: 1000)));
      // attempt 2: baseDelay * 2^1 = 2000ms * 1.0 jitter = 2000ms
      expect(service.calculateDelay(2), equals(Duration(milliseconds: 2000)));
      // attempt 3: baseDelay * 2^2 = 4000ms * 1.0 jitter = 4000ms
      expect(service.calculateDelay(3), equals(Duration(milliseconds: 4000)));
    });

    test('caps delay at max delay', () {
      final service = OverpassPoiService(
        random: _FixedRandom(1.0),
      );

      // attempt 5: baseDelay * 2^4 = 16000ms, capped to 8000ms * 1.0 = 8000ms
      expect(service.calculateDelay(5), equals(Duration(milliseconds: 8000)));
    });

    test('applies jitter to reduce thundering herd', () {
      // With random = 0.0: jitter = 0.5 + 0.0 * 0.5 = 0.5
      final service = OverpassPoiService(
        random: _FixedRandom(0.0),
      );

      // attempt 1: 1000ms * 0.5 = 500ms
      expect(service.calculateDelay(1), equals(Duration(milliseconds: 500)));
      // attempt 2: 2000ms * 0.5 = 1000ms
      expect(service.calculateDelay(2), equals(Duration(milliseconds: 1000)));
    });

    test('delay is always within bounds', () {
      final random = Random(42);
      final service = OverpassPoiService(random: random);

      for (var attempt = 1; attempt <= 10; attempt++) {
        final delay = service.calculateDelay(attempt);
        // Min jitter = 0.5, so min delay for attempt 1 = 500ms
        expect(delay.inMilliseconds, greaterThan(0));
        // Max delay with max jitter = 8000ms * ~1.0 = 8000ms
        expect(delay.inMilliseconds, lessThanOrEqualTo(8000));
      }
    });
  });
}
