// test/services/poi_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_service.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/models/poi.dart';

void main() {
  group('PoiService', () {
    late MockApiClient mockClient;
    late PoiService service;

    setUp(() {
      mockClient = MockApiClient();
      service = PoiService(apiClient: mockClient);
    });

    test('should fetch POIs in bounds with scoring', () async {
      // Arrange
      const mockNearbyResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "National Museum",
              "lat": 32.0741,
              "lon": 34.7924
            }
          ]
        }
      }
      ''';
      const mockDescriptionResponse = '''
      {
        "query": {
          "pages": {
            "12345": {
              "extract": "The National Museum is a major cultural institution founded in 1950."
            }
          }
        }
      }
      ''';
      
      mockClient.setWikipediaNearbyResponse(mockNearbyResponse);
      mockClient.setResponse('wikipedia.org/w/api.php', mockDescriptionResponse);

      // Act
      final result = await service.fetchInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        maxResults: 10,
      );

      // Assert
      expect(result, isNotEmpty);
      expect(result[0], isA<Poi>());
      expect(result[0].name, equals('National Museum'));
      expect(result[0].interestScore, greaterThan(0.0));
      expect(result[0].category, equals(PoiCategory.museum));
      expect(result[0].interestLevel, equals(PoiInterestLevel.high));
    });

    test('should maintain backward compatibility with legacy fetchNearby', () async {
      // Act
      final result = await service.fetchNearby(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(2)); // Default mock returns 2 POIs
      expect(result[0], isA<Poi>());
      expect(result[0].name, equals('Test Location 1'));
      expect(result[0].interestScore, greaterThanOrEqualTo(0.0));
    });

    test('should clear caches', () {
      // Act & Assert - should not throw
      expect(() => service.clearCaches(), returnsNormally);
    });

    test('should convert WikipediaPoi to Poi correctly', () async {
      // Arrange
      const mockResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Test Museum",
              "lat": 32.0741,
              "lon": 34.7924
            }
          ]
        }
      }
      ''';
      mockClient.setWikipediaNearbyResponse(mockResponse);

      // Act
      final result = await service.fetchNearby(32.0741, 34.7924);

      // Assert
      final poi = result[0];
      expect(poi.id, equals(poi.name)); // ID should be the title
      expect(poi.lat, equals(32.0741));
      expect(poi.lon, equals(34.7924));
      expect(poi.audio, equals('')); // Audio should be empty initially
      expect(poi.category, isA<PoiCategory>());
      expect(poi.interestLevel, isA<PoiInterestLevel>());
    });
  });
}