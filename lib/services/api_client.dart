// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Abstract interface for making HTTP requests
abstract class ApiClient {
  /// Makes a GET request to the specified URL
  /// Returns the response body as a string if successful
  /// Throws an exception if the request fails
  Future<String> get(Uri url);

  /// Makes a POST request to the specified URL with body
  /// Returns the response body as a string if successful
  /// Throws an exception if the request fails
  Future<String> post(Uri url, String body);
}

/// Production implementation that makes real HTTP requests
class HttpApiClient implements ApiClient {
  final http.Client? _httpClient;

  HttpApiClient(this._httpClient);

  @override
  Future<String> get(Uri url) async {
    final client = _httpClient ?? http.Client();
    final response = await client.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('HTTP ${response.statusCode}: Failed to fetch $url');
    }
  }

  @override
  Future<String> post(Uri url, String body) async {
    final client = _httpClient ?? http.Client();
    final response = await client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('HTTP ${response.statusCode}: Failed to post to $url');
    }
  }
}

/// Mock implementation for testing
class MockApiClient implements ApiClient {
  final Map<String, String> _responses = {};

  /// Configure a response for a specific URL pattern
  void setResponse(String urlPattern, String response) {
    _responses[urlPattern] = response;
  }

  /// Configure Wikipedia nearby POIs response
  void setWikipediaNearbyResponse(String response) {
    setResponse('wikipedia.org/w/api.php', response);
  }

  @override
  Future<String> get(Uri url) async {
    // For OSRM routing API (both old and new endpoints)
    if (url.toString().contains('router.project-osrm.org') ||
        url.toString().contains('routing.openstreetmap.de') ||
        url.toString().contains('/route/v1/foot/') ||
        url.toString().contains('/routed-foot/route/v1/foot/')) {
      return jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'distance': 1000.0,
            'duration': 720.0, // 12 minutes
            'geometry': {
              'coordinates': [
                [34.7924, 32.0741], // Start [lon, lat]
                [34.7928, 32.0745],
                [34.7932, 32.0748],
                [34.7934, 32.0751], // End [lon, lat]
              ],
              'type': 'LineString',
            },
            'legs': [
              {
                'steps': [
                  {
                    'distance': 300.0,
                    'duration': 216.0,
                    'name': 'Test Street',
                    'maneuver': {'type': 'depart', 'modifier': null},
                  },
                  {
                    'distance': 400.0,
                    'duration': 288.0,
                    'name': 'Main Avenue',
                    'maneuver': {'type': 'turn', 'modifier': 'left'},
                  },
                  {
                    'distance': 300.0,
                    'duration': 216.0,
                    'name': 'Destination Road',
                    'maneuver': {'type': 'turn', 'modifier': 'right'},
                  },
                  {
                    'distance': 0.0,
                    'duration': 0.0,
                    'name': '',
                    'maneuver': {'type': 'arrive', 'modifier': null},
                  },
                ],
              },
            ],
          },
        ],
        'waypoints': [
          {
            'location': [34.7924, 32.0741],
            'name': 'Start',
          },
          {
            'location': [34.7934, 32.0751],
            'name': 'End',
          },
        ],
      });
    }

    // For Wikipedia API, check query parameters to determine response type
    if (url.toString().contains('wikipedia.org/w/api.php')) {
      if (url.queryParameters['action'] == 'query' &&
          url.queryParameters['list'] == 'search') {
        // New search API for infix/substring matching
        for (final pattern in _responses.keys) {
          if (pattern.contains('search') || url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultSearchResponse();
      } else if (url.queryParameters['action'] == 'opensearch') {
        // Check if there's a configured opensearch response
        for (final pattern in _responses.keys) {
          if (pattern.contains('opensearch') ||
              url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultOpensearchResponse();
      } else if (url.queryParameters['list'] == 'geosearch') {
        // Check if there's a configured geosearch response
        for (final pattern in _responses.keys) {
          if (pattern.contains('geosearch') ||
              url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultNearbyResponse();
      } else if (url.queryParameters['prop'] == 'extracts') {
        // Check if there's a configured extracts response
        for (final pattern in _responses.keys) {
          if (pattern.contains('extracts') ||
              url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultDescriptionResponse();
      } else if (url.queryParameters['prop'] == 'pageimages') {
        // Check if there's a configured pageimages response
        for (final pattern in _responses.keys) {
          if (pattern.contains('pageimages') ||
              url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultPageImageResponse();
      } else if (url.queryParameters['prop'] == 'pageprops') {
        // Check if there's a configured pageprops response
        for (final pattern in _responses.keys) {
          if (pattern.contains('pageprops') ||
              url.toString().contains(pattern)) {
            return _responses[pattern]!;
          }
        }
        return _getDefaultPagePropsResponse();
      } else if (url.queryParameters['prop'] == 'coordinates') {
        // Check if there's a configured coordinates response based on title
        final titles = url.queryParameters['titles'];
        if (titles != null) {
          final normalizedTitle = titles.replaceAll(' ', '_');
          for (final pattern in _responses.keys) {
            if (pattern == normalizedTitle ||
                url.toString().contains(pattern)) {
              return _responses[pattern]!;
            }
          }
        }
        return _getDefaultCoordinatesResponse();
      }
    }

    // Find matching response based on URL pattern
    for (final pattern in _responses.keys) {
      if (url.toString().contains(pattern)) {
        return _responses[pattern]!;
      }
    }

    throw Exception('Mock: No response configured for $url');
  }

  String _getDefaultNearbyResponse() {
    return jsonEncode({
      'query': {
        'geosearch': [
          {'title': 'Test Location 1', 'lat': 32.0741, 'lon': 34.7924},
          {'title': 'Test Location 2', 'lat': 32.0751, 'lon': 34.7934},
        ],
      },
    });
  }

  String _getDefaultDescriptionResponse() {
    return jsonEncode({
      'query': {
        'pages': {
          '123': {
            'extract': 'This is a test description for a Wikipedia article.',
          },
        },
      },
    });
  }

  String _getDefaultPageImageResponse() {
    return jsonEncode({
      'query': {
        'pages': {
          '123': {
            'thumbnail': {
              'source': 'https://example.com/test-poi-image.jpg',
            },
          },
        },
      },
    });
  }

  String _getDefaultPagePropsResponse() {
    return jsonEncode({
      'query': {
        'pages': {
          '123': {
            'pageprops': {'wikibase_item': 'Q123'},
          },
        },
      },
    });
  }

  String _getDefaultOpensearchResponse() {
    return jsonEncode([
      'search query',
      ['Test Result 1', 'Test Result 2'],
      ['Description 1', 'Description 2'],
      [
        'https://en.wikipedia.org/wiki/Test_Result_1',
        'https://en.wikipedia.org/wiki/Test_Result_2',
      ],
    ]);
  }

  String _getDefaultSearchResponse() {
    return jsonEncode({
      'query': {
        'search': [
          {
            'title': 'Test Result 1',
            'snippet': 'This is a test <span>description</span> for result 1',
          },
          {
            'title': 'Test Result 2',
            'snippet': 'This is a test description for result 2',
          },
        ],
      },
    });
  }

  String _getDefaultCoordinatesResponse() {
    return jsonEncode({
      'query': {
        'pages': {
          '123': {
            'coordinates': [
              {'lat': 32.0741, 'lon': 34.7924},
            ],
          },
        },
      },
    });
  }

  @override
  Future<String> post(Uri url, String body) async {
    // Mock implementation for POST requests
    // For routing service, return a simple mock response
    if (url.toString().contains('openrouteservice')) {
      return jsonEncode({
        'routes': [
          {
            'summary': {
              'distance': 1000.0,
              'duration': 720.0, // 12 minutes
            },
            'geometry': [
              [34.7924, 32.0741],
              [34.7934, 32.0751],
            ],
            'segments': [
              {
                'steps': [
                  {
                    'instruction': 'Head north',
                    'distance': 500.0,
                    'type': 0,
                    'way_points': [0],
                  },
                  {
                    'instruction': 'Turn right',
                    'distance': 500.0,
                    'type': 1,
                    'way_points': [1],
                  },
                ],
              },
            ],
          },
        ],
      });
    }

    throw Exception('Mock: No POST response configured for $url');
  }
}
