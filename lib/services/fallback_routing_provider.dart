import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'routing_provider.dart';

/// Fallback routing provider that creates straight-line routes
/// Used when no other routing provider is available
class FallbackRoutingProvider implements RoutingProvider {
  @override
  String get providerName => 'Fallback';

  @override
  bool get requiresApiKey => false;

  @override
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    final distance = const Distance().distance(start, destination);

    // Calculate estimated walking time (assuming 5 km/h walking speed)
    final durationSeconds = (distance / 1.39); // 1.39 m/s ≈ 5 km/h

    // Create simple straight-line route with interpolated points
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
