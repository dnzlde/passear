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
      
      mockClient.setWikipediaNearbyResponse(mockNearbyResponse);

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
      // Description should not be loaded initially for performance
      expect(result[0].isDescriptionLoaded, isFalse);
      expect(result[0].description, equals(''));
    });

    test('should maintain backward compatibility with legacy fetchNearby', () async {
      // Act
      final result = await service.fetchNearby(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(2)); // Default mock returns 2 POIs
      expect(result[0], isA<Poi>());
      expect(result[0].name, equals('Test Location 1'));
      expect(result[0].interestScore, greaterThanOrEqualTo(0.0));
      // Legacy method should still load descriptions for backward compatibility
      expect(result[0].isDescriptionLoaded, isTrue);
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
      expect(poi.isDescriptionLoaded, isA<bool>());
    });

    test('should fetch POI description on demand', () async {
      // Arrange
      const mockDescriptionResponse = '''
      {
        "query": {
          "pages": {
            "12345": {
              "extract": "Test Museum is a fascinating place with rich history."
            }
          }
        }
      }
      ''';
      mockClient.setResponse('wikipedia.org/w/api.php', mockDescriptionResponse);

      final poi = Poi(
        id: 'test-museum',
        name: 'Test Museum',
        lat: 32.0741,
        lon: 34.7924,
        description: '',
        audio: '',
        isDescriptionLoaded: false,
      );

      // Act
      final result = await service.fetchPoiDescription(poi);

      // Assert
      expect(result.isDescriptionLoaded, isTrue);
      expect(result.description, contains('fascinating place'));
      expect(result.name, equals(poi.name)); // Other fields should remain the same
      expect(result.lat, equals(poi.lat));
      expect(result.lon, equals(poi.lon));
    });

    test('should return same POI if description already loaded', () async {
      // Arrange
      final poi = Poi(
        id: 'test-poi',
        name: 'Test POI',
        lat: 32.0741,
        lon: 34.7924,
        description: 'Already loaded description',
        audio: '',
        isDescriptionLoaded: true,
      );

      // Act
      final result = await service.fetchPoiDescription(poi);

      // Assert
      expect(result, equals(poi)); // Should return the same POI instance
      expect(result.description, equals('Already loaded description'));
    });
  });
}