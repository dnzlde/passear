import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'routing_provider.dart';
import 'osrm_routing_provider.dart';
import 'fallback_routing_provider.dart';
import 'api_client.dart';

/// Main routing service that manages multiple routing providers
/// This service provides an abstraction layer to easily switch between
/// different routing providers (OSRM, Google Maps, OpenRouteService, etc.)
class RoutingService {
  final RoutingProvider _primaryProvider;
  final RoutingProvider _fallbackProvider;

  RoutingService({
    RoutingProvider? primaryProvider,
    RoutingProvider? fallbackProvider,
    ApiClient? apiClient,
  })  : _primaryProvider =
            primaryProvider ?? OsrmRoutingProvider(apiClient: apiClient),
        _fallbackProvider = fallbackProvider ?? FallbackRoutingProvider();

  /// Get the current primary routing provider name
  String get currentProviderName => _primaryProvider.providerName;

  /// Fetch a pedestrian route from start to destination
  /// Tries the primary provider first, then falls back if it fails
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      // Try primary provider first
      final route = await _primaryProvider.getRoute(
        start: start,
        destination: destination,
      );

      if (route != null) {
        debugPrint('Route calculated using ${_primaryProvider.providerName}');
        return route;
      }

      // Primary provider returned null, use fallback
      debugPrint(
        '${_primaryProvider.providerName} provider returned no route, using ${_fallbackProvider.providerName}',
      );
      return await _fallbackProvider.getRoute(
        start: start,
        destination: destination,
      );
    } catch (e) {
      // Primary provider failed, use fallback
      debugPrint(
        'Error with ${_primaryProvider.providerName} provider, using ${_fallbackProvider.providerName}: $e',
      );
      return await _fallbackProvider.getRoute(
        start: start,
        destination: destination,
      );
    }
  }
}
