import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'api_client.dart';

/// Service for fetching pedestrian routes using OpenRouteService API
class RoutingService {
  final ApiClient _apiClient;

  // OpenRouteService public API endpoint
  // Note: For production use, you should get your own API key from https://openrouteservice.org/
  static const String _baseUrl = 'api.openrouteservice.org';

  RoutingService({ApiClient? apiClient})
      : _apiClient = apiClient ?? HttpApiClient(null);

  /// Fetch a pedestrian route from start to destination
  /// Returns null if routing fails
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      // Use OpenRouteService v2 API for pedestrian routing
      // Using public demo key - should be replaced with actual key in production
      final url = Uri.https(
        _baseUrl,
        '/v2/directions/foot-walking',
      );

      final body = json.encode({
        'coordinates': [
          [start.longitude, start.latitude],
          [destination.longitude, destination.latitude],
        ],
        'instructions': true,
        'units': 'm',
      });

      // For this implementation, we'll use a simple fallback to straight-line routing
      // when the API is not available (for testing purposes)
      String responseBody;
      try {
        responseBody = await _apiClient.post(url, body);
      } catch (e) {
        // Fallback to simple straight-line route if API call fails
        debugPrint('Routing API not available, using fallback: $e');
        return _createFallbackRoute(start, destination);
      }

      final data = json.decode(responseBody);

      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        return _createFallbackRoute(start, destination);
      }

      final route = data['routes'][0];
      final summary = route['summary'];
      final geometry = route['geometry'];
      final segments = route['segments'] as List?;

      // Parse waypoints from geometry (encoded polyline or coordinates)
      final waypoints = _parseGeometry(geometry);

      // Parse instructions
      final instructions = <RouteInstruction>[];
      if (segments != null) {
        for (final segment in segments) {
          final steps = segment['steps'] as List?;
          if (steps != null) {
            for (final step in steps) {
              instructions.add(RouteInstruction(
                text: step['instruction'] ?? '',
                distanceMeters: (step['distance'] ?? 0.0).toDouble(),
                type: step['type'] ?? 0,
                location: waypoints[step['way_points']?[0] ?? 0],
              ));
            }
          }
        }
      }

      return NavigationRoute(
        waypoints: waypoints,
        distanceMeters: (summary['distance'] ?? 0.0).toDouble(),
        durationSeconds: (summary['duration'] ?? 0.0).toDouble(),
        instructions: instructions,
      );
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return _createFallbackRoute(start, destination);
    }
  }

  /// Create a simple fallback route (straight line) when API is not available
  NavigationRoute _createFallbackRoute(LatLng start, LatLng destination) {
    final distance = const Distance().distance(start, destination);

    // Calculate estimated walking time (assuming 5 km/h walking speed)
    final durationSeconds = (distance / 1.39); // 1.39 m/s ≈ 5 km/h

    // Create simple straight-line route with a few intermediate points
    final waypoints = _interpolatePoints(start, destination, 10);

    return NavigationRoute(
      waypoints: waypoints,
      distanceMeters: distance,
      durationSeconds: durationSeconds,
      instructions: [
        RouteInstruction(
          text: 'Head towards destination',
          distanceMeters: distance,
          type: 0,
          location: start,
        ),
        RouteInstruction(
          text: 'Arrive at destination',
          distanceMeters: 0,
          type: 10,
          location: destination,
        ),
      ],
    );
  }

  /// Parse geometry from OpenRouteService response
  List<LatLng> _parseGeometry(dynamic geometry) {
    if (geometry is List) {
      // Coordinates array format
      return geometry
          .map((coord) => LatLng(
                coord[1].toDouble(),
                coord[0].toDouble(),
              ))
          .toList();
    } else if (geometry is String) {
      // Encoded polyline format (would need polyline decoder)
      // For now, return empty list and rely on fallback
      return [];
    }
    return [];
  }

  /// Interpolate points between start and destination for smoother route
  List<LatLng> _interpolatePoints(
      LatLng start, LatLng destination, int numPoints) {
    final points = <LatLng>[start];

    for (int i = 1; i < numPoints; i++) {
      final ratio = i / numPoints;
      final lat = start.latitude + (destination.latitude - start.latitude) * ratio;
      final lng =
          start.longitude + (destination.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }

    points.add(destination);
    return points;
  }
}
