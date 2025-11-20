// lib/services/google_directions_provider.dart
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'routing_provider.dart';

/// Google Directions API routing provider
/// Note: This is a stub implementation. To use this provider:
/// 1. Add Google Directions API key to your project
/// 2. Enable Google Directions API in Google Cloud Console
/// 3. Implement proper API calls with authentication
class GoogleDirectionsProvider implements RoutingProvider {
  @override
  String get providerName => 'Google Directions';

  @override
  bool get requiresApiKey => true;

  @override
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    // TODO: Implement Google Directions API integration
    // For now, return null to trigger fallback
    throw UnimplementedError(
      'Google Directions provider requires API key configuration. '
      'Please configure your Google Directions API key to use this provider.',
    );
  }
}
