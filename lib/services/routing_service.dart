import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../models/settings.dart' as settings;
import 'routing_provider.dart';
import 'osrm_routing_provider.dart';
import 'fallback_routing_provider.dart';
import 'google_directions_provider.dart';
import 'api_client.dart';

/// Main routing service that manages multiple routing providers
/// This service provides an abstraction layer to easily switch between
/// different routing providers (OSRM, Google Maps, OpenRouteService, etc.)
class RoutingService {
  RoutingProvider? _primaryProvider;
  final RoutingProvider _fallbackProvider;
  final ApiClient? _apiClient;

  RoutingService({
    RoutingProvider? primaryProvider,
    RoutingProvider? fallbackProvider,
    ApiClient? apiClient,
  })  : _primaryProvider = primaryProvider,
        _fallbackProvider = fallbackProvider ?? FallbackRoutingProvider(),
        _apiClient = apiClient;

  /// Create routing provider based on settings
  RoutingProvider _createProvider(settings.RoutingProvider providerType) {
    switch (providerType) {
      case settings.RoutingProvider.osrm:
        return OsrmRoutingProvider(apiClient: _apiClient);
      case settings.RoutingProvider.googleDirections:
        return GoogleDirectionsProvider();
    }
  }

  /// Update the routing provider based on settings
  void updateProvider(settings.RoutingProvider providerType) {
    _primaryProvider = _createProvider(providerType);
  }

  /// Get the primary provider (create default if not set)
  RoutingProvider get _provider {
    _primaryProvider ??= OsrmRoutingProvider(apiClient: _apiClient);
    return _primaryProvider!;
  }

  /// Get the current primary routing provider name
  String get currentProviderName => _provider.providerName;

  /// Fetch a pedestrian route from start to destination
  /// Tries the primary provider first, then falls back if it fails
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    try {
      // Try primary provider first
      final route = await _provider.getRoute(
        start: start,
        destination: destination,
      );

      if (route != null) {
        debugPrint('Route calculated using ${_provider.providerName}');
        return route;
      }

      // Primary provider returned null, use fallback
      debugPrint(
        '${_provider.providerName} provider returned no route, using ${_fallbackProvider.providerName}',
      );
      return await _fallbackProvider.getRoute(
        start: start,
        destination: destination,
      );
    } catch (e) {
      // Primary provider failed, use fallback
      debugPrint(
        'Error with ${_provider.providerName} provider, using ${_fallbackProvider.providerName}: $e',
      );
      return await _fallbackProvider.getRoute(
        start: start,
        destination: destination,
      );
    }
  }
}
