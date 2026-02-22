// test/services/api_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/api_client.dart';
import 'dart:convert';

void main() {
  group('MockApiClient', () {
    late MockApiClient mockClient;

    setUp(() {
      mockClient = MockApiClient();
    });

    test(
      'should return configured response for matching URL pattern',
      () async {
        // Arrange
        const expectedResponse = '{"test": "data"}';
        mockClient.setResponse('example.com', expectedResponse);
        final url = Uri.parse('https://example.com/api/test');

        // Act
        final result = await mockClient.get(url);

        // Assert
        expect(result, expectedResponse);
      },
    );

    test(
      'should return default Wikipedia nearby response for geosearch',
      () async {
        // Arrange
        final url = Uri.https('en.wikipedia.org', '/w/api.php', {
          'action': 'query',
          'format': 'json',
          'list': 'geosearch',
          'gscoord': '32.0741|34.7924',
          'gsradius': '1000',
          'gslimit': '10',
        });

        // Act
        final result = await mockClient.get(url);
        final data = jsonDecode(result);

        // Assert
        expect(data['query']['geosearch'], isA<List>());
        expect(data['query']['geosearch'].length, equals(2));
        expect(
          data['query']['geosearch'][0]['title'],
          equals('Test Location 1'),
        );
        expect(data['query']['geosearch'][0]['lat'], equals(32.0741));
        expect(data['query']['geosearch'][0]['lon'], equals(34.7924));
      },
    );

    test(
      'should return default Wikipedia description response for extracts',
      () async {
        // Arrange
        final url = Uri.https('en.wikipedia.org', '/w/api.php', {
          'action': 'query',
          'format': 'json',
          'prop': 'extracts',
          'exintro': '1',
          'explaintext': '1',
          'titles': 'Test Title',
        });

        // Act
        final result = await mockClient.get(url);
        final data = jsonDecode(result);

        // Assert
        expect(data['query']['pages'], isA<Map>());
        expect(
          data['query']['pages']['123']['extract'],
          contains('test description'),
        );
      },
    );

    test('should throw exception for unconfigured URL', () async {
      // Arrange
      final url = Uri.parse('https://unknown.com/api');

      // Act & Assert
      expect(
        () => mockClient.get(url),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No response configured'),
          ),
        ),
      );
    });

    test(
        'should throw ApiRequestCancelledException when cancelled before request',
        () async {
      // Arrange
      const expectedResponse = '{"test": "data"}';
      mockClient.setResponse('example.com', expectedResponse);
      final url = Uri.parse('https://example.com/api/test');
      final cancelToken = ApiCancellationToken();

      // Cancel before making request
      cancelToken.cancel();

      // Act & Assert
      expect(
        () => mockClient.get(url, cancelToken: cancelToken),
        throwsA(isA<ApiRequestCancelledException>()),
      );
    });

    test('should complete normally when cancelToken is not cancelled',
        () async {
      // Arrange
      const expectedResponse = '{"test": "data"}';
      mockClient.setResponse('example.com', expectedResponse);
      final url = Uri.parse('https://example.com/api/test');
      final cancelToken = ApiCancellationToken();

      // Act
      final result = await mockClient.get(url, cancelToken: cancelToken);

      // Assert
      expect(result, expectedResponse);
      expect(cancelToken.isCancelled, false);
    });
  });

  group('ApiCancellationToken', () {
    test('should start with isCancelled = false', () {
      // Arrange & Act
      final token = ApiCancellationToken();

      // Assert
      expect(token.isCancelled, false);
    });

    test('should set isCancelled = true when cancel() is called', () {
      // Arrange
      final token = ApiCancellationToken();

      // Act
      token.cancel();

      // Assert
      expect(token.isCancelled, true);
    });

    test('should reset isCancelled to false when reset() is called', () {
      // Arrange
      final token = ApiCancellationToken();
      token.cancel();
      expect(token.isCancelled, true);

      // Act
      token.reset();

      // Assert
      expect(token.isCancelled, false);
    });

    test('should allow multiple cancel calls', () {
      // Arrange
      final token = ApiCancellationToken();

      // Act
      token.cancel();
      token.cancel();
      token.cancel();

      // Assert
      expect(token.isCancelled, true);
    });
  });

  group('HttpApiClient cancellation', () {
    test(
        'should throw ApiRequestCancelledException when cancelled before GET request',
        () async {
      // Arrange
      final client = HttpApiClient(null);
      final url =
          Uri.parse('https://httpbin.org/delay/5'); // Would take 5 seconds
      final cancelToken = ApiCancellationToken();

      // Cancel before making request
      cancelToken.cancel();

      // Act & Assert
      expect(
        () => client.get(url, cancelToken: cancelToken),
        throwsA(isA<ApiRequestCancelledException>()),
      );
    });

    test(
        'should throw ApiRequestCancelledException when cancelled before POST request',
        () async {
      // Arrange
      final client = HttpApiClient(null);
      final url = Uri.parse('https://httpbin.org/delay/5');
      final body = '{"test": "data"}';
      final cancelToken = ApiCancellationToken();

      // Cancel before making request
      cancelToken.cancel();

      // Act & Assert
      expect(
        () => client.post(url, body, cancelToken: cancelToken),
        throwsA(isA<ApiRequestCancelledException>()),
      );
    });
  });
}
