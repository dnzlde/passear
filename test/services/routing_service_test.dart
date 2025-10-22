import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passear/services/routing_service.dart';
import 'package:passear/services/api_client.dart';

void main() {
  group('RoutingService', () {
    late RoutingService routingService;
    late MockApiClient mockApiClient;

    setUp(() {
      mockApiClient = MockApiClient();
      routingService = RoutingService(apiClient: mockApiClient);
    });

    test('should fetch route successfully with mock API', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(route!.waypoints, isNotEmpty);
      expect(route.distanceMeters, greaterThan(0));
      expect(route.durationSeconds, greaterThan(0));
    });

    test('should format distance correctly', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(route!.formattedDistance, matches(RegExp(r'\d+(\.\d+)? (m|km)')));
    });

    test('should format duration correctly', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(
          route!.formattedDuration, matches(RegExp(r'\d+ min|(\d+h \d+m)')));
    });

    test('should return fallback route when API fails', () async {
      // Use a MockApiClient that doesn't have routing response configured
      final failingClient = MockApiClient();
      final failingService = RoutingService(apiClient: failingClient);

      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await failingService.getRoute(
        start: start,
        destination: destination,
      );

      // Should still return a fallback route
      expect(route, isNotNull);
      expect(route!.waypoints, isNotEmpty);
      expect(route.distanceMeters, greaterThan(0));
      expect(route.instructions, hasLength(2)); // Start and end instructions
    });

    test('should include navigation instructions', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(route!.instructions, isNotEmpty);
      expect(route.instructions.first.text, isNotEmpty);
    });

    test('should calculate distance between start and destination', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      // Distance should be positive and reasonable
      expect(route!.distanceMeters, greaterThan(0));
      expect(route.distanceMeters, lessThan(10000)); // Less than 10km
    });

    test('should provide interpolated waypoints for smoother route', () async {
      final start = LatLng(32.0741, 34.7924);
      final destination = LatLng(32.0751, 34.7934);

      final route = await routingService.getRoute(
        start: start,
        destination: destination,
      );

      expect(route, isNotNull);
      expect(route!.waypoints.length, greaterThanOrEqualTo(2));
      expect(route.waypoints.first.latitude, closeTo(start.latitude, 0.0001));
      expect(
          route.waypoints.first.longitude, closeTo(start.longitude, 0.0001));
      expect(
          route.waypoints.last.latitude, closeTo(destination.latitude, 0.0001));
      expect(route.waypoints.last.longitude,
          closeTo(destination.longitude, 0.0001));
    });
  });
}
