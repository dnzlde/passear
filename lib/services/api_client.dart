// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Abstract interface for making HTTP requests
abstract class ApiClient {
  /// Makes a GET request to the specified URL
  /// Returns the response body as a string if successful
  /// Throws an exception if the request fails
  Future<String> get(Uri url);
}

/// Production implementation that makes real HTTP requests
class HttpApiClient implements ApiClient {
  final http.Client _httpClient;
  
  HttpApiClient(this._httpClient);
  
  @override
  Future<String> get(Uri url) async {
    final response = await _httpClient.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('HTTP ${response.statusCode}: Failed to fetch $url');
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
    // Find matching response based on URL
    for (final pattern in _responses.keys) {
      if (url.toString().contains(pattern)) {
        return _responses[pattern]!;
      }
    }
    
    // Default mock responses for common requests
    if (url.toString().contains('wikipedia.org/w/api.php')) {
      if (url.queryParameters['list'] == 'geosearch') {
        return _getDefaultNearbyResponse();
      } else if (url.queryParameters['prop'] == 'extracts') {
        return _getDefaultDescriptionResponse();
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
}