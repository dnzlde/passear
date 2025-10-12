// test/integration/lazy_loading_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_service.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/models/poi.dart';

void main() {
  group('Lazy Loading Integration', () {
    late MockApiClient mockClient;
    late PoiService service;

    setUp(() {
      mockClient = MockApiClient();
      service = PoiService(apiClient: mockClient);
    });

    test('should demonstrate lazy loading workflow', () async {
      // Arrange - Setup mock responses
      const mockNearbyResponse = '''
      {
        "query": {
          "geosearch": [
            {
              "title": "Historic Museum",
              "lat": 32.0741,
              "lon": 34.7924
            },
            {
              "title": "Central Park",
              "lat": 32.0751,
              "lon": 34.7934
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
              "extract": "Historic Museum is a renowned cultural institution established in 1950, featuring extensive collections of art and artifacts from various historical periods."
            }
          }
        }
      }
      ''';

      // Configure mock to return geosearch response for nearby requests
      // and description response for extracts requests
      // Since both use the same URL pattern, we'll use the default behavior
      // by not configuring a specific response, letting the mock handle it based on query params
      
      // Actually, let's configure it properly by setting the geosearch response
      mockClient.setResponse('geosearch', mockNearbyResponse);
      mockClient.setResponse('extracts', mockDescriptionResponse);

      // Act 1: Initial fetch (should not load descriptions)
      final initialPois = await service.fetchInBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.79,
        maxResults: 10,
      );

      // Assert 1: POIs should be loaded without descriptions
      expect(initialPois, hasLength(2));
      final museum =
          initialPois.firstWhere((poi) => poi.name.contains('Museum'));
      expect(museum.name, equals('Historic Museum'));
      expect(museum.category.name, equals('museum'));
      expect(museum.interestLevel.name, equals('high'));
      expect(museum.isDescriptionLoaded, isFalse);
      expect(museum.description, isEmpty);

      // Act 2: User taps on POI, trigger description loading
      final enrichedPoi = await service.fetchPoiDescription(museum);

      // Assert 2: Description should now be loaded
      expect(enrichedPoi.isDescriptionLoaded, isTrue);
      expect(enrichedPoi.description, isNotEmpty);
      expect(enrichedPoi.description, contains('cultural institution'));
      expect(enrichedPoi.description, contains('established in 1950'));
      // Other properties should remain the same
      expect(enrichedPoi.name, equals(museum.name));
      expect(enrichedPoi.lat, equals(museum.lat));
      expect(enrichedPoi.lon, equals(museum.lon));
      expect(enrichedPoi.category, equals(museum.category));
    });

    test('should handle the case where description loading fails gracefully',
        () async {
      // Arrange - Setup POI and configure mock to return null/empty description
      const mockEmptyDescriptionResponse = '''
      {
        "query": {
          "pages": {
            "12345": {}
          }
        }
      }
      ''';
      
      mockClient.setResponse(
          'wikipedia.org/w/api.php', mockEmptyDescriptionResponse);
      
      final poi = Poi(
        id: 'unknown-poi',
        name: 'Unknown POI',
        lat: 32.0741,
        lon: 34.7924,
        description: '',
        audio: '',
        isDescriptionLoaded: false,
      );

      // Act - Try to fetch description (will return null/empty)
      final result = await service.fetchPoiDescription(poi);

      // Assert - Should return original POI gracefully
      expect(result.name, equals(poi.name));
      expect(result.isDescriptionLoaded, isFalse);
      expect(result.description, isEmpty);
    });

    test('should not refetch description if already loaded', () async {
      // Arrange
      final poi = Poi(
        id: 'loaded-poi',
        name: 'Loaded POI',
        lat: 32.0741,
        lon: 34.7924,
        description: 'Already loaded description',
        audio: '',
        isDescriptionLoaded: true,
      );

      // Act
      final result = await service.fetchPoiDescription(poi);

      // Assert - Should return the same POI without making API calls
      expect(identical(result, poi), isTrue);
      expect(result.description, equals('Already loaded description'));
    });
  });
}
