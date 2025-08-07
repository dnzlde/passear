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

    test('should fetch nearby POIs with descriptions and scoring', () async {
      // Arrange
      const nearbyResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Tel Aviv Museum of Art",
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
              "extract": "The Tel Aviv Museum of Art is a major art museum in Tel Aviv, Israel. Founded in 1932, it houses one of Israel's largest collections of modern and contemporary art."
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
      expect(result[0].title, equals('Tel Aviv Museum of Art'));
      expect(result[0].description, contains('major art museum'));
      expect(result[0].interestScore, greaterThan(0.0));
      expect(result[0].category.name, equals('museum'));
      expect(result[0].interestLevel.name, equals('high'));
    });

    test('should use default mock responses when no specific response configured', () async {
      // Act
      final result = await service.fetchNearbyPois(32.0741, 34.7924);

      // Assert
      expect(result, hasLength(2));
      expect(result[0].title, equals('Test Location 1'));
      expect(result[1].title, equals('Test Location 2'));
    });

    test('should fetch intelligent POIs in bounds', () async {
      // Arrange
      const nearbyResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Tel Aviv Museum of Art",
              "lat": 32.0741,
              "lon": 34.7924
            },
            {
              "title": "Generic Building",
              "lat": 32.0751,
              "lon": 34.7934
            }
          ]
        }
      }
      ''';
      
      mockClient.setWikipediaNearbyResponse(nearbyResponse);

      // Act
      final result = await service.fetchIntelligentPoisInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        maxResults: 5,
      );

      // Assert
      expect(result, isNotEmpty);
      // Museum should score higher and appear first
      final museum = result.firstWhere((poi) => poi.title.contains('Museum'), orElse: () => result.first);
      expect(museum.interestScore, greaterThan(10.0));
      expect(museum.category.name, equals('museum'));
      // Descriptions should not be loaded in intelligent bounds fetching
      expect(museum.description, isNull);
    });

    test('should clear caches when requested', () async {
      // Arrange - make a call to populate cache
      await service.fetchDescription('Test Title');

      // Act
      service.clearCaches();

      // Assert - no way to directly test cache clearing, but method should not throw
      expect(() => service.clearCaches(), returnsNormally);
    });

    test('should enrich single POI with description on demand', () async {
      // Arrange
      const mockDescriptionResponse = '''
      {
        "query": {
          "pages": {
            "12345": {
              "extract": "This is a detailed description loaded on demand."
            }
          }
        }
      }
      ''';
      mockClient.setResponse('wikipedia.org/w/api.php', mockDescriptionResponse);

      final poi = WikipediaPoi(
        title: 'Test POI',
        lat: 32.0741,
        lon: 34.7924,
      );

      // Act
      await service.enrichPoiWithDescription(poi);

      // Assert
      expect(poi.description, equals('This is a detailed description loaded on demand.'));
      expect(poi.interestScore, greaterThan(0.0)); // Score should be recalculated
    });

    test('should skip enrichment if description already exists', () async {
      // Arrange
      final poi = WikipediaPoi(
        title: 'Test POI',
        lat: 32.0741,
        lon: 34.7924,
        description: 'Existing description',
      );

      // Act
      await service.enrichPoiWithDescription(poi);

      // Assert
      expect(poi.description, equals('Existing description')); // Should remain unchanged
    });
  });
}