import 'dart:async';

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

void main() {
  group('OverpassPoiService', () {
    test('retries once on HTTP 429 and succeeds', () async {
      final apiClient = _SequentialApiClient([
        Exception('HTTP 429: Failed to fetch'),
        '{"elements":[]}',
      ]);
      final service = OverpassPoiService(apiClient: apiClient);

      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );

      expect(pois, isEmpty);
      expect(apiClient.callCount, equals(2));
    });

    test('retries once on timeout and succeeds', () async {
      final apiClient = _SequentialApiClient([
        TimeoutException('Overpass timed out'),
        '{"elements":[]}',
      ]);
      final service = OverpassPoiService(apiClient: apiClient);

      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
      );

      expect(pois, isEmpty);
      expect(apiClient.callCount, equals(2));
    });
  });
}
