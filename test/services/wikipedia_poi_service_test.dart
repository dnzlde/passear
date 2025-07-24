// test/services/wikipedia_poi_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/wikipedia_poi_service.dart';
import 'package:passear/services/api_client.dart';
import 'dart:convert';

void main() {
  group('WikipediaPoiService', () {
    late MockApiClient mockClient;
    late WikipediaPoiService service;

    setUp(() {
      mockClient = MockApiClient();
      service = WikipediaPoiService(apiClient: mockClient);
    });

    test('should fetch nearby POIs successfully', () async {
      // Arrange
      const mockResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Tel Aviv Museum",
              "lat": 32.0741,
              "lon": 34.7924
            },
            {
              "title": "Azrieli Center",
              "lat": 32.0751,
              "lon": 34.7934
            }
          ]
        }
      }
      ''';
      mockClient.setWikipediaNearbyResponse(mockResponse);

      // Act
      final result = await service.fetchNearbyPois(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(2));
      expect(result[0].title, equals('Tel Aviv Museum'));
      expect(result[0].lat, equals(32.0741));
      expect(result[0].lon, equals(34.7924));
      expect(result[1].title, equals('Azrieli Center'));
      expect(result[1].lat, equals(32.0751));
      expect(result[1].lon, equals(34.7934));
    });

    test('should fetch description successfully', () async {
      // Arrange
      const mockResponse = '''
      {
        "query": {
          "pages": {
            "12345": {
              "extract": "Tel Aviv Museum of Art is a major art museum in Tel Aviv, Israel."
            }
          }
        }
      }
      ''';
      mockClient.setResponse('wikipedia.org/w/api.php', mockResponse);

      // Act
      final result = await service.fetchDescription('Tel Aviv Museum');

      // Assert
      expect(result, equals('Tel Aviv Museum of Art is a major art museum in Tel Aviv, Israel.'));
    });

    test('should handle description fetch failure gracefully', () async {
      // Arrange - no response configured, will throw exception

      // Act
      final result = await service.fetchDescription('Unknown Title');

      // Assert
      expect(result, isNull);
    });

    test('should fetch nearby POIs with descriptions', () async {
      // Arrange
      const nearbyResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Test Location",
              "lat": 32.0741,
              "lon": 34.7924
            }
          ]
        }
      }
      ''';
      const descriptionResponse = '''
      {
        "query": {
          "pages": {
            "12345": {
              "extract": "Test description for the location."
            }
          }
        }
      }
      ''';
      
      mockClient.setWikipediaNearbyResponse(nearbyResponse);
      mockClient.setResponse('wikipedia.org/w/api.php', descriptionResponse);

      // Act
      final result = await service.fetchNearbyWithDescriptions(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(1));
      expect(result[0].title, equals('Test Location'));
      expect(result[0].description, equals('Test description for the location.'));
    });

    test('should use default mock responses when no specific response configured', () async {
      // Act
      final result = await service.fetchNearbyPois(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(2));
      expect(result[0].title, equals('Test Location 1'));
      expect(result[1].title, equals('Test Location 2'));
    });
  });
}