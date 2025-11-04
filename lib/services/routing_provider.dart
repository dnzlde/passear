import 'package:latlong2/latlong.dart';
import '../models/route.dart';

/// Abstract interface for routing providers
/// This allows switching between different routing services (OSRM, Google Maps, etc.)
abstract class RoutingProvider {
  /// Fetch a pedestrian route from start to destination
  /// Returns null if routing fails
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  });

  /// Get the name of this routing provider
  String get providerName;

  /// Check if this provider requires an API key
  bool get requiresApiKey;
}
