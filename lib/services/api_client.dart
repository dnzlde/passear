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
    // For Wikipedia API, check query parameters to determine response type
    if (url.toString().contains('wikipedia.org/w/api.php')) {
      if (url.queryParameters['list'] == 'geosearch') {
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
          {
            'title': 'Test Location 1',
            'lat': 32.0741,
            'lon': 34.7924,
          },
          {
            'title': 'Test Location 2',
            'lat': 32.0751,
            'lon': 34.7934,
          }
        ]
      }
    });
  }

  String _getDefaultDescriptionResponse() {
    return jsonEncode({
      'query': {
        'pages': {
          '123': {
            'extract': 'This is a test description for a Wikipedia article.'
          }
        }
      }
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
                ]
              }
            ]
          }
        ]
      });
    }

    throw Exception('Mock: No POST response configured for $url');
  }
}
