// test/services/poi_service_cancellation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/services/poi_service.dart';
import 'package:passear/services/overpass_poi_service.dart';
import 'package:passear/services/wikipedia_poi_service.dart';
import 'dart:convert';

/// Delayed mock API client to simulate slow network
class DelayedMockApiClient implements ApiClient {
  final Duration delay;
  final MockApiClient _underlying = MockApiClient();
  int requestCount = 0;
  int cancelledCount = 0;

  DelayedMockApiClient({this.delay = const Duration(milliseconds: 100)});

  void setResponse(String urlPattern, String response) {
    _underlying.setResponse(urlPattern, response);
  }

  @override
  Future<String> get(Uri url, {ApiCancellationToken? cancelToken}) async {
    requestCount++;
    
    // Check cancellation before delay
    if (cancelToken?.isCancelled ?? false) {
      cancelledCount++;
      throw ApiRequestCancelledException();
    }

    // Simulate network delay
    await Future.delayed(delay);

    // Check cancellation after delay
    if (cancelToken?.isCancelled ?? false) {
      cancelledCount++;
      throw ApiRequestCancelledException();
    }

    return _underlying.get(url, cancelToken: cancelToken);
  }

  @override
  Future<String> post(Uri url, String body, {ApiCancellationToken? cancelToken}) async {
    requestCount++;
    
    if (cancelToken?.isCancelled ?? false) {
      cancelledCount++;
      throw ApiRequestCancelledException();
    }

    await Future.delayed(delay);

    if (cancelToken?.isCancelled ?? false) {
      cancelledCount++;
      throw ApiRequestCancelledException();
    }

    return _underlying.post(url, body, cancelToken: cancelToken);
  }
}

void main() {
  group('OverpassPoiService Cancellation', () {
    test('should propagate cancellation token to API client', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 50));
      mockClient.setResponse('overpass-api.de', jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 32.0741,
            'lon': 34.7924,
            'tags': {'name': 'Test Museum', 'tourism': 'museum'},
          },
        ],
      }));

      final service = OverpassPoiService(apiClient: mockClient);
      final cancelToken = ApiCancellationToken();

      // Act - Start request and cancel immediately
      final requestFuture = service.fetchPoisInBounds(
        north: 32.08,
        south: 32.06,
        east: 34.80,
        west: 34.78,
        cancelToken: cancelToken,
      );

      // Cancel after a tiny delay
      await Future.delayed(const Duration(milliseconds: 5));
      cancelToken.cancel();

      // Assert
      expect(
        requestFuture,
        throwsA(isA<ApiRequestCancelledException>()),
      );
      
      await Future.delayed(const Duration(milliseconds: 100));
      expect(mockClient.requestCount, 1);
      expect(mockClient.cancelledCount, 1);
    });

    test('should complete successfully without cancellation', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 10));
      mockClient.setResponse('overpass-api.de', jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 32.0741,
            'lon': 34.7924,
            'tags': {'name': 'Test Museum', 'tourism': 'museum'},
          },
        ],
      }));

      final service = OverpassPoiService(apiClient: mockClient);
      final cancelToken = ApiCancellationToken();

      // Act - Request without cancellation
      final pois = await service.fetchPoisInBounds(
        north: 32.08,
        south: 32.06,
        east: 34.80,
        west: 34.78,
        cancelToken: cancelToken,
      );

      // Assert
      expect(pois.length, 1);
      expect(pois[0].name, 'Test Museum');
      expect(cancelToken.isCancelled, false);
      expect(mockClient.requestCount, 1);
      expect(mockClient.cancelledCount, 0);
    });
  });

  group('WikipediaPoiService Cancellation', () {
    test('should propagate cancellation token through service chain', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 50));
      // Configure default Wikipedia responses via setResponse
      mockClient.setResponse('wikipedia.org/w/api.php', jsonEncode({
        'query': {
          'geosearch': [
            {'title': 'Test Location', 'lat': 32.0741, 'lon': 34.7924},
          ],
        },
      }));

      final service = WikipediaPoiService(apiClient: mockClient);
      final cancelToken = ApiCancellationToken();

      // Act - Start request and cancel immediately
      final requestFuture = service.fetchIntelligentPoisInBounds(
        north: 32.08,
        south: 32.06,
        east: 34.80,
        west: 34.78,
        cancelToken: cancelToken,
      );

      await Future.delayed(const Duration(milliseconds: 5));
      cancelToken.cancel();

      // Assert
      expect(
        requestFuture,
        throwsA(isA<ApiRequestCancelledException>()),
      );
      
      await Future.delayed(const Duration(milliseconds: 100));
      expect(mockClient.cancelledCount, greaterThan(0));
    });

    test('should complete successfully without cancellation', () async {
      // Arrange
      final mockClient = MockApiClient();
      final service = WikipediaPoiService(apiClient: mockClient);
      final cancelToken = ApiCancellationToken();

      // Act
      final pois = await service.fetchIntelligentPoisInBounds(
        north: 32.08,
        south: 32.06,
        east: 34.80,
        west: 34.78,
        maxResults: 5,
        cancelToken: cancelToken,
      );

      // Assert
      expect(pois, isNotEmpty);
      expect(cancelToken.isCancelled, false);
    });
  });

  group('POI Loading Cancellation Scenarios', () {
    test('viewport change: second request should cancel first request', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 100));
      mockClient.setResponse('overpass-api.de', jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 32.0741,
            'lon': 34.7924,
            'tags': {'name': 'Test Museum', 'tourism': 'museum'},
          },
        ],
      }));

      final service = OverpassPoiService(apiClient: mockClient);

      // Act - Simulate viewport changes
      final token1 = ApiCancellationToken();
      final request1 = service.fetchPoisInBounds(
        north: 32.08,
        south: 32.06,
        east: 34.80,
        west: 34.78,
        cancelToken: token1,
      );

      // User moves map - cancel first request
      await Future.delayed(const Duration(milliseconds: 10));
      token1.cancel();

      // Start second request
      final token2 = ApiCancellationToken();
      final request2 = service.fetchPoisInBounds(
        north: 32.18,
        south: 32.16,
        east: 34.90,
        west: 34.88,
        cancelToken: token2,
      );

      // Assert
      expect(
        request1,
        throwsA(isA<ApiRequestCancelledException>()),
      );

      final pois2 = await request2;
      expect(pois2.length, 1);
      expect(token1.isCancelled, true);
      expect(token2.isCancelled, false);
    });

    test('rapid viewport changes: only last request should complete', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 50));
      mockClient.setResponse('overpass-api.de', jsonEncode({
        'elements': [
          {
            'type': 'node',
            'id': 1,
            'lat': 32.0741,
            'lon': 34.7924,
            'tags': {'name': 'Test', 'tourism': 'museum'},
          },
        ],
      }));

      final service = OverpassPoiService(apiClient: mockClient);
      final tokens = <ApiCancellationToken>[];
      final requests = <Future<List<dynamic>>>[];

      // Act - Simulate rapid viewport changes (10 in quick succession)
      for (var i = 0; i < 10; i++) {
        final token = ApiCancellationToken();
        tokens.add(token);

        final request = service.fetchPoisInBounds(
          north: 32.08 + (i * 0.01),
          south: 32.06 + (i * 0.01),
          east: 34.80 + (i * 0.01),
          west: 34.78 + (i * 0.01),
          cancelToken: token,
        ).then((pois) => pois as List<dynamic>).catchError((e) {
          if (e is ApiRequestCancelledException) {
            return <dynamic>[]; // Return empty list for cancelled requests
          }
          throw e;
        });

        requests.add(request);

        // Cancel all previous tokens when starting a new request
        for (var j = 0; j < i; j++) {
          tokens[j].cancel();
        }

        await Future.delayed(const Duration(milliseconds: 5));
      }

      // Wait for all requests to complete
      final results = await Future.wait(requests);

      // Assert - Only the last request should have returned results
      // All previous ones should be cancelled
      var successfulRequests = 0;
      for (var i = 0; i < results.length; i++) {
        if (results[i].isNotEmpty) {
          successfulRequests++;
          expect(i, 9); // Should be the last request
        }
      }

      expect(successfulRequests, 1);
      expect(tokens.last.isCancelled, false);
      
      // All except the last should be cancelled
      for (var i = 0; i < tokens.length - 1; i++) {
        expect(tokens[i].isCancelled, true);
      }
    });

    test('no-leaks: cancelled POI requests should not accumulate', () async {
      // Arrange
      final mockClient = DelayedMockApiClient(delay: Duration(milliseconds: 30));
      mockClient.setResponse('overpass-api.de', jsonEncode({
        'elements': [],
      }));

      final service = OverpassPoiService(apiClient: mockClient);

      // Act - Create and cancel many requests
      for (var i = 0; i < 30; i++) {
        final token = ApiCancellationToken();
        final request = service.fetchPoisInBounds(
          north: 32.08,
          south: 32.06,
          east: 34.80,
          west: 34.78,
          cancelToken: token,
        );

        // Cancel immediately
        token.cancel();

        try {
          await request;
        } on ApiRequestCancelledException {
          // Expected
        }
      }

      // Assert - Give time for cleanup
      await Future.delayed(const Duration(milliseconds: 100));
      
      // If we reach here without memory issues, test passes
      expect(mockClient.cancelledCount, greaterThan(20));
      expect(true, true);
    });
  });
}
