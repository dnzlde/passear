import 'package:latlong2/latlong.dart';
import '../models/poi.dart';
import 'poi_service.dart';
import 'llm_service.dart';

/// Service for managing the AI guide chat feature
class GuideChatService {
  final PoiService _poiService;
  final LlmService _llmService;

  /// Radius in meters to search for nearby POIs
  static const int searchRadiusMeters = 250;

  /// Maximum number of POIs to include in context
  static const int maxPoisInContext = 5;

  GuideChatService({
    required PoiService poiService,
    required LlmService llmService,
  })  : _poiService = poiService,
        _llmService = llmService;

  /// Get nearby POIs around the given location
  Future<List<Poi>> getNearbyPois(LatLng location) async {
    return await _poiService.fetchNearby(
      location.latitude,
      location.longitude,
      radius: searchRadiusMeters,
    );
  }

  /// Ask the guide a question about nearby POIs
  /// Returns the AI's response or throws an error
  Future<String> askGuide({
    required String question,
    required LatLng userLocation,
  }) async {
    // Get nearby POIs
    final nearbyPois = await getNearbyPois(userLocation);

    // Check if there are any POIs nearby
    if (nearbyPois.isEmpty) {
      throw GuideChatException(
        'No points of interest found nearby. Try moving to a different location or zooming out on the map.',
      );
    }

    // Load descriptions for POIs that don't have them yet
    final poisWithDescriptions = <Poi>[];
    for (final poi in nearbyPois.take(maxPoisInContext)) {
      final updatedPoi = await _poiService.fetchPoiDescription(poi);
      poisWithDescriptions.add(updatedPoi);
    }

    // Build context from POIs
    final poisContext = poisWithDescriptions.map((poi) {
      return {'name': poi.name, 'description': poi.description};
    }).toList();

    // Ask the LLM
    try {
      return await _llmService.chatWithGuide(
        userQuestion: question,
        poisContext: poisContext,
      );
    } catch (e) {
      throw GuideChatException(
        'Failed to get response from guide: ${e.toString()}',
      );
    }
  }
}

/// Exception thrown by guide chat service
class GuideChatException implements Exception {
  final String message;

  GuideChatException(this.message);

  @override
  String toString() => message;
}
