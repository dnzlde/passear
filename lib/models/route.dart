import 'package:latlong2/latlong.dart';

/// Represents a navigation route from start to destination
class NavigationRoute {
  final List<LatLng> waypoints;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteInstruction> instructions;

  NavigationRoute({
    required this.waypoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.instructions,
  });

  /// Format distance in human-readable form
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Format duration in human-readable form
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }
}

/// Represents a single navigation instruction
class RouteInstruction {
  final String text;
  final double distanceMeters;
  final int type; // Instruction type (e.g., turn left, turn right, straight)
  final LatLng location;

  RouteInstruction({
    required this.text,
    required this.distanceMeters,
    required this.type,
    required this.location,
  });

  /// Format distance for instruction
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
