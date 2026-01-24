// test/services/poi_search_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/poi_search_service.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/models/poi.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('PoiSearchService', () {
    late MockApiClient mockClient;
    late PoiSearchService service;

    setUp(() {
      mockClient = MockApiClient();
      service = PoiSearchService(apiClient: mockClient);
    });

    test('should return empty list for empty query', () async {
      // Act
      final results = await service.searchPois(query: '');

      // Assert
      expect(results, isEmpty);
    });

    test('should search Wikipedia and return POIs with coordinates', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {
              "title": "Western Wall",
              "snippet": "Holy site in Jerusalem"
            },
            {
              "title": "Temple Mount",
              "snippet": "Religious site in Old City"
            }
          ]
        }
      }
      ''';

      const coordinatesResponse1 = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 31.7767, "lon": 35.2345}
              ]
            }
          }
        }
      }
      ''';

      const coordinatesResponse2 = '''
      {
        "query": {
          "pages": {
            "456": {
              "coordinates": [
                {"lat": 31.7781, "lon": 35.2360}
              ]
            }
          }
        }
      }
      ''';

      // Configure mock responses
      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Western_Wall', coordinatesResponse1);
      mockClient.setResponse('Temple_Mount', coordinatesResponse2);

      // Act
      final results = await service.searchPois(query: 'Wailing Wall');

      // Assert
      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results[0].poi.name, equals('Western Wall'));
      expect(results[0].poi.lat, equals(31.7767));
      expect(results[0].poi.lon, equals(35.2345));
      expect(results[0].relevanceScore, greaterThan(0));
    });

    test('should filter out results without coordinates', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {
              "title": "Place With Coords",
              "snippet": "Description 1"
            },
            {
              "title": "Place Without Coords",
              "snippet": "Description 2"
            }
          ]
        }
      }
      ''';

      const coordinatesResponse1 = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 31.7767, "lon": 35.2345}
              ]
            }
          }
        }
      }
      ''';

      const coordinatesResponse2 = '''
      {
        "query": {
          "pages": {
            "456": {}
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Place_With_Coords', coordinatesResponse1);
      mockClient.setResponse('Place_Without_Coords', coordinatesResponse2);

      // Act
      final results = await service.searchPois(query: 'test');

      // Assert
      expect(results.length, equals(1));
      expect(results[0].poi.name, equals('Place With Coords'));
    });

    test('should score POIs higher when close to user location', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {
              "title": "Close Museum",
              "snippet": "Museum nearby"
            },
            {
              "title": "Far Museum",
              "snippet": "Museum far away"
            }
          ]
        }
      }
      ''';

      const nearbyCoords = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 32.0741, "lon": 34.7924}
              ]
            }
          }
        }
      }
      ''';

      const farCoords = '''
      {
        "query": {
          "pages": {
            "456": {
              "coordinates": [
                {"lat": 40.7128, "lon": -74.0060}
              ]
            }
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Close_Museum', nearbyCoords);
      mockClient.setResponse('Far_Museum', farCoords);

      // Act - User in Tel Aviv area
      final results = await service.searchPois(
        query: 'museum',
        userLocation: const LatLng(32.0741, 34.7924),
      );

      // Assert
      expect(results.length, equals(2));
      // Close Museum should have higher relevance score
      expect(results[0].poi.name, equals('Close Museum'));
      expect(
        results[0].relevanceScore,
        greaterThan(results[1].relevanceScore),
      );
    });

    test('should score POIs higher when in visible map bounds', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {
              "title": "Visible Site",
              "snippet": "In view"
            },
            {
              "title": "Hidden Site",
              "snippet": "Out of view"
            }
          ]
        }
      }
      ''';

      const visibleCoords = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 32.075, "lon": 34.79}
              ]
            }
          }
        }
      }
      ''';

      const hiddenCoords = '''
      {
        "query": {
          "pages": {
            "456": {
              "coordinates": [
                {"lat": 50.0, "lon": 50.0}
              ]
            }
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Visible_Site', visibleCoords);
      mockClient.setResponse('Hidden_Site', hiddenCoords);

      // Act - Map bounds around Tel Aviv
      final results = await service.searchPois(
        query: 'site',
        mapBounds: MapBounds(
          north: 32.08,
          south: 32.07,
          east: 34.80,
          west: 34.78,
        ),
      );

      // Assert
      expect(results.length, equals(2));
      // Visible Site should have higher relevance score
      expect(results[0].poi.name, equals('Visible Site'));
      expect(
        results[0].relevanceScore,
        greaterThan(results[1].relevanceScore),
      );
    });

    test('should respect limit parameter', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {"title": "Result 1", "snippet": "Desc 1"},
            {"title": "Result 2", "snippet": "Desc 2"},
            {"title": "Result 3", "snippet": "Desc 3"},
            {"title": "Result 4", "snippet": "Desc 4"},
            {"title": "Result 5", "snippet": "Desc 5"}
          ]
        }
      }
      ''';

      // Configure coordinates for all results
      for (int i = 1; i <= 5; i++) {
        mockClient.setResponse(
          'Result_$i',
          '''
          {
            "query": {
              "pages": {
                "$i": {
                  "coordinates": [
                    {"lat": 32.0, "lon": 34.0}
                  ]
                }
              }
            }
          }
          ''',
        );
      }

      mockClient.setResponse('search', searchResponse);

      // Act
      final results = await service.searchPois(
        query: 'test',
        limit: 3,
      );

      // Assert
      expect(results.length, lessThanOrEqualTo(3));
    });

    test('should handle Wikipedia API errors gracefully', () async {
      // Arrange - Configure invalid JSON response that will cause parsing error
      mockClient.setResponse('search', 'invalid json {{{');

      // Act & Assert - Should return empty list instead of throwing
      final results = await service.searchPois(query: 'test query');
      expect(results, isEmpty);
    });

    test('should handle missing descriptions', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {"title": "Place Name", "snippet": ""}
          ]
        }
      }
      ''';

      const coordinatesResponse = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 32.0741, "lon": 34.7924}
              ]
            }
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Place_Name', coordinatesResponse);

      // Act
      final results = await service.searchPois(query: 'test');

      // Assert
      expect(results, isNotEmpty);
      expect(results[0].poi.description, equals(''));
    });

    test('should calculate higher scores for better text matches', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {"title": "Exact Match", "snippet": "First result"},
            {"title": "Partial Match", "snippet": "Second result"}
          ]
        }
      }
      ''';

      const coords1 = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 32.0, "lon": 34.0}
              ]
            }
          }
        }
      }
      ''';

      const coords2 = '''
      {
        "query": {
          "pages": {
            "456": {
              "coordinates": [
                {"lat": 32.0, "lon": 34.0}
              ]
            }
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('Exact_Match', coords1);
      mockClient.setResponse('Partial_Match', coords2);

      // Act
      final results = await service.searchPois(query: 'test');

      // Assert
      expect(results.length, equals(2));
      // First result from Wikipedia should have higher match score
      expect(
        results[0].relevanceScore,
        greaterThanOrEqualTo(results[1].relevanceScore),
      );
    });

    test('should set POI categories and interest scores', () async {
      // Arrange
      const searchResponse = '''
      {
        "query": {
          "search": [
            {"title": "National Museum", "snippet": "Important museum"}
          ]
        }
      }
      ''';

      const coordinatesResponse = '''
      {
        "query": {
          "pages": {
            "123": {
              "coordinates": [
                {"lat": 32.0741, "lon": 34.7924}
              ]
            }
          }
        }
      }
      ''';

      mockClient.setResponse('search', searchResponse);
      mockClient.setResponse('National_Museum', coordinatesResponse);

      // Act
      final results = await service.searchPois(query: 'test');

      // Assert
      expect(results, isNotEmpty);
      expect(results[0].poi.category, equals(PoiCategory.museum));
      expect(results[0].poi.interestScore, greaterThan(0));
    });
  });

  group('MapBounds', () {
    test('should create map bounds with correct values', () {
      // Act
      final bounds = MapBounds(
        north: 32.08,
        south: 32.07,
        east: 34.80,
        west: 34.78,
      );

      // Assert
      expect(bounds.north, equals(32.08));
      expect(bounds.south, equals(32.07));
      expect(bounds.east, equals(34.80));
      expect(bounds.west, equals(34.78));
    });
  });

  group('PoiSearchResult', () {
    test('should create search result with POI and score', () {
      // Arrange
      final poi = Poi(
        id: 'test',
        name: 'Test POI',
        lat: 32.0,
        lon: 34.0,
        description: 'Test',
        audio: '',
      );

      // Act
      final result = PoiSearchResult(
        poi: poi,
        relevanceScore: 85.5,
        matchedText: 'Test POI',
      );

      // Assert
      expect(result.poi, equals(poi));
      expect(result.relevanceScore, equals(85.5));
      expect(result.matchedText, equals('Test POI'));
    });
  });
}
