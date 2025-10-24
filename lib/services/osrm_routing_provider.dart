import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'api_client.dart';
import 'routing_provider.dart';

/// OSRM (Open Source Routing Machine) implementation of routing provider
/// Uses a public OSRM server with OpenStreetMap data
/// Note: The public demo server may have limited pedestrian routing support
class OsrmRoutingProvider implements RoutingProvider {
  final ApiClient _apiClient;

  // Using a public OSRM server
  // Note: router.project-osrm.org primarily supports car routing
  // For better pedestrian routing, consider using GraphHopper or hosting your own OSRM
  static const String _baseUrl = 'routing.openstreetmap.de';

  OsrmRoutingProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? HttpApiClient(null);

  @override
  String get providerName => 'OSRM';

  @override
  bool get requiresApiKey => false;

  @override
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      // Use OSRM API for pedestrian routing with foot profile
      // routing.openstreetmap.de has proper foot routing that ignores one-way restrictions
      final url = Uri.https(
        _baseUrl,
        '/routed-foot/route/v1/foot/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
        {
          'steps': 'true',
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': 'false',
        },
      );

      final responseBody = await _apiClient.get(url);
      final data = json.decode(responseBody);

      // Check if the request was successful
      if (data['code'] != 'Ok' || 
          data['routes'] == null || 
          (data['routes'] as List).isEmpty) {
        debugPrint('OSRM API returned no routes');
        return null;
      }

      final route = data['routes'][0];
      final geometry = route['geometry'];
      final legs = route['legs'] as List?;

      // Parse waypoints from GeoJSON geometry
      final waypoints = _parseGeoJsonGeometry(geometry);

      if (waypoints.isEmpty) {
        debugPrint('Failed to parse route geometry');
        return null;
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
              
              String instruction = _getInstructionText(maneuver, step);
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
      debugPrint('Error fetching route from OSRM: $e');
      return null;
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
        return 1;
      case 'depart':
        return 0;
      case 'arrive':
        return 10;
      case 'continue':
        return 6;
      case 'roundabout':
      case 'rotary':
        return 7;
      default:
        return 0;
    }
  }
}
