import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'api_client.dart';

/// Service for fetching pedestrian routes using OSRM (Open Source Routing Machine)
class RoutingService {
  final ApiClient _apiClient;

  // OSRM public API endpoint - free to use, no API key required
  // Uses OpenStreetMap data for routing
  static const String _baseUrl = 'router.project-osrm.org';

  RoutingService({ApiClient? apiClient})
      : _apiClient = apiClient ?? HttpApiClient(null);

  /// Fetch a pedestrian route from start to destination
  /// Returns null if routing fails
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      // Use OSRM API for pedestrian routing (foot profile)
      // Format: /route/v1/{profile}/{coordinates}?steps=true&overview=full
      final url = Uri.https(
        _baseUrl,
        '/route/v1/foot/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
        {
          'steps': 'true',
          'overview': 'full',
          'geometries': 'geojson',
        },
      );

      String responseBody;
      try {
        responseBody = await _apiClient.get(url);
      } catch (e) {
        // Fallback to simple straight-line route if API call fails
        debugPrint('Routing API not available, using fallback: $e');
        return _createFallbackRoute(start, destination);
      }

      final data = json.decode(responseBody);

      // Check if the request was successful
      if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
        debugPrint('OSRM API returned no routes, using fallback');
        return _createFallbackRoute(start, destination);
      }

      final route = data['routes'][0];
      final geometry = route['geometry'];
      final legs = route['legs'] as List?;

      // Parse waypoints from GeoJSON geometry
      final waypoints = _parseGeoJsonGeometry(geometry);

      if (waypoints.isEmpty) {
        debugPrint('Failed to parse route geometry, using fallback');
        return _createFallbackRoute(start, destination);
      }

      // Parse instructions from legs/steps
      final instructions = <RouteInstruction>[];
      if (legs != null && legs.isNotEmpty) {
        for (final leg in legs) {
          final steps = leg['steps'] as List?;
          if (steps != null) {
            for (int i = 0; i < steps.length; i++) {
              final step = steps[i];
              final maneuver = step['maneuver'];
              
              // Get instruction text
              String instruction = _getInstructionText(maneuver, step);
              
              // Get step location from waypoint
              final location = waypoints.length > i 
                  ? waypoints[i] 
                  : waypoints[0];
              
              instructions.add(RouteInstruction(
                text: instruction,
                distanceMeters: (step['distance'] ?? 0.0).toDouble(),
                type: _getManeuverType(maneuver['type']),
                location: location,
              ));
            }
          }
        }
      }

      // Add arrival instruction if not present
      if (instructions.isEmpty || instructions.last.type != 10) {
        instructions.add(RouteInstruction(
          text: 'Arrive at destination',
          distanceMeters: 0,
          type: 10,
          location: destination,
        ));
      }

      return NavigationRoute(
        waypoints: waypoints,
        distanceMeters: (route['distance'] ?? 0.0).toDouble(),
        durationSeconds: (route['duration'] ?? 0.0).toDouble(),
        instructions: instructions,
      );
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return _createFallbackRoute(start, destination);
    }
  }

  /// Parse GeoJSON geometry to list of LatLng points
  List<LatLng> _parseGeoJsonGeometry(dynamic geometry) {
    if (geometry == null) return [];
    
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null) return [];

    return coordinates.map((coord) {
      if (coord is List && coord.length >= 2) {
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }
      return null;
    }).whereType<LatLng>().toList();
  }

  /// Get human-readable instruction text from OSRM maneuver
  String _getInstructionText(dynamic maneuver, dynamic step) {
    if (maneuver == null) return 'Continue';
    
    final type = maneuver['type'] as String?;
    final modifier = maneuver['modifier'] as String?;
    final name = step['name'] as String?;
    
    String instruction = '';
    
    switch (type) {
      case 'depart':
        instruction = 'Start on ${name ?? "the path"}';
        break;
      case 'arrive':
        instruction = 'Arrive at destination';
        break;
      case 'turn':
        if (modifier != null) {
          instruction = 'Turn ${modifier.replaceAll('-', ' ')}';
          if (name != null && name.isNotEmpty) {
            instruction += ' onto $name';
          }
        } else {
          instruction = 'Turn';
        }
        break;
      case 'new name':
        instruction = 'Continue on ${name ?? "the path"}';
        break;
      case 'continue':
        instruction = 'Continue straight';
        if (name != null && name.isNotEmpty) {
          instruction += ' on $name';
        }
        break;
      case 'roundabout':
        instruction = 'Enter roundabout';
        break;
      case 'rotary':
        instruction = 'Enter rotary';
        break;
      case 'end of road':
        instruction = 'At the end of the road, turn ${modifier ?? ""}';
        break;
      default:
        instruction = 'Continue';
    }
    
    return instruction;
  }

  /// Map OSRM maneuver type to instruction type code
  int _getManeuverType(String? type) {
    switch (type) {
      case 'turn':
        return 1; // Turn
      case 'depart':
        return 0; // Start
      case 'arrive':
        return 10; // Arrive
      case 'continue':
        return 6; // Continue straight
      case 'roundabout':
      case 'rotary':
        return 7; // Roundabout
      default:
        return 0; // Default
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
