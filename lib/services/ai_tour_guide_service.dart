// lib/services/ai_tour_guide_service.dart
import '../models/poi.dart';

/// Abstract interface for AI tour guiding service.
/// This can be implemented with different AI backends (mock, OpenAI, etc.)
abstract class AiTourGuideService {
  /// Generate a personalized tour guide narration for a POI.
  ///
  /// [poi] - The point of interest to generate narration for
  /// [nearbyPois] - Optional list of nearby POIs for context
  /// [userContext] - Optional additional context about the user/tour
  ///
  /// Returns a tour guide style narration string
  Future<String> generateNarration({
    required Poi poi,
    List<Poi>? nearbyPois,
    String? userContext,
  });

  /// Generate a brief introduction for a POI when approaching it.
  ///
  /// Returns a short, engaging teaser about the POI
  Future<String> generateApproachTeaser(Poi poi);

  /// Generate a contextual transition between two POIs.
  ///
  /// [fromPoi] - The POI the user is leaving
  /// [toPoi] - The POI the user is approaching
  ///
  /// Returns a narration that connects the two POIs
  Future<String> generateTransition({
    required Poi fromPoi,
    required Poi toPoi,
  });

  /// Check if the service is available and ready to use.
  Future<bool> isAvailable();

  /// Dispose of any resources used by the service.
  Future<void> dispose();
}

/// Mock implementation of AiTourGuideService that generates
/// contextual narrations without requiring an actual AI API.
/// This serves as a template for future AI integrations.
class MockAiTourGuideService implements AiTourGuideService {
  // Simulated delay to mimic API call
  final Duration _simulatedDelay;

  MockAiTourGuideService({
    Duration? simulatedDelay,
  }) : _simulatedDelay = simulatedDelay ?? const Duration(milliseconds: 500);

  @override
  Future<String> generateNarration({
    required Poi poi,
    List<Poi>? nearbyPois,
    String? userContext,
  }) async {
    await Future.delayed(_simulatedDelay);

    final categoryIntro = _getCategoryIntro(poi.category);
    final interestComment = _getInterestComment(poi.interestLevel);
    final contextualAddition = _getContextualAddition(poi, nearbyPois);

    // Build a tour guide style narration
    final narration = StringBuffer();

    narration.writeln('Welcome to ${poi.name}!');
    narration.writeln();
    narration.writeln(categoryIntro);
    narration.writeln();

    if (poi.description.isNotEmpty) {
      narration.writeln(_enhanceDescription(poi.description, poi.category));
      narration.writeln();
    }

    narration.writeln(interestComment);

    if (contextualAddition.isNotEmpty) {
      narration.writeln();
      narration.writeln(contextualAddition);
    }

    return narration.toString().trim();
  }

  @override
  Future<String> generateApproachTeaser(Poi poi) async {
    await Future.delayed(_simulatedDelay);

    final teasers = _getApproachTeasers(poi);
    // Simple rotation based on POI id hash
    final index = poi.id.hashCode.abs() % teasers.length;
    return teasers[index];
  }

  @override
  Future<String> generateTransition({
    required Poi fromPoi,
    required Poi toPoi,
  }) async {
    await Future.delayed(_simulatedDelay);

    final fromCategory = _getCategoryName(fromPoi.category);
    final toCategory = _getCategoryName(toPoi.category);

    if (fromPoi.category == toPoi.category) {
      return 'Continuing our exploration of ${fromCategory.toLowerCase()}s, '
          'let\'s now visit ${toPoi.name}, another fascinating example '
          'in this area.';
    }

    return 'From the $fromCategory at ${fromPoi.name}, we now make our way '
        'to ${toPoi.name}, a $toCategory that offers a different perspective '
        'on this neighborhood\'s rich heritage.';
  }

  @override
  Future<bool> isAvailable() async {
    // Mock service is always available
    return true;
  }

  @override
  Future<void> dispose() async {
    // No resources to dispose in mock implementation
  }

  String _getCategoryIntro(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return 'You\'ve arrived at a museum, a treasure trove of culture '
            'and history waiting to be explored.';
      case PoiCategory.historicalSite:
        return 'This historical site stands as a testament to the events '
            'that shaped this region.';
      case PoiCategory.landmark:
        return 'Before you stands one of the area\'s most recognizable '
            'landmarks, a symbol of local pride.';
      case PoiCategory.religiousSite:
        return 'This sacred space has served the spiritual needs of the '
            'community for generations.';
      case PoiCategory.park:
        return 'Welcome to this green oasis, a place where nature and urban '
            'life come together.';
      case PoiCategory.monument:
        return 'This monument commemorates important figures or events in '
            'the area\'s history.';
      case PoiCategory.university:
        return 'You\'re visiting an institution of learning that has shaped '
            'countless minds over the years.';
      case PoiCategory.theater:
        return 'This venue has hosted countless performances, bringing art '
            'and entertainment to the community.';
      case PoiCategory.gallery:
        return 'Step into this gallery where artistic expression takes '
            'center stage.';
      case PoiCategory.architecture:
        return 'The architectural design before you tells a story of style, '
            'innovation, and craftsmanship.';
      case PoiCategory.generic:
        return 'This interesting location offers a unique glimpse into '
            'the character of the area.';
    }
  }

  String _getInterestComment(PoiInterestLevel level) {
    switch (level) {
      case PoiInterestLevel.high:
        return 'This is one of the most notable attractions in the area, '
            'highly recommended for any visitor!';
      case PoiInterestLevel.medium:
        return 'A worthwhile stop that adds depth to your exploration '
            'of this neighborhood.';
      case PoiInterestLevel.low:
        return 'While perhaps lesser known, this spot offers its own '
            'unique charm for the curious explorer.';
    }
  }

  String _getCategoryName(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return 'Museum';
      case PoiCategory.historicalSite:
        return 'Historical Site';
      case PoiCategory.landmark:
        return 'Landmark';
      case PoiCategory.religiousSite:
        return 'Religious Site';
      case PoiCategory.park:
        return 'Park';
      case PoiCategory.monument:
        return 'Monument';
      case PoiCategory.university:
        return 'University';
      case PoiCategory.theater:
        return 'Theater';
      case PoiCategory.gallery:
        return 'Gallery';
      case PoiCategory.architecture:
        return 'Architectural Site';
      case PoiCategory.generic:
        return 'Point of Interest';
    }
  }

  String _enhanceDescription(String description, PoiCategory category) {
    // Add tour guide style framing to the description
    final prefix = _getDescriptionPrefix(category);
    final suffix = _getDescriptionSuffix(category);

    // Truncate very long descriptions for narration
    String truncatedDesc = description;
    if (description.length > 500) {
      final lastPeriod = description.substring(0, 500).lastIndexOf('.');
      if (lastPeriod > 200) {
        truncatedDesc = description.substring(0, lastPeriod + 1);
      } else {
        truncatedDesc = '${description.substring(0, 497)}...';
      }
    }

    return '$prefix $truncatedDesc $suffix';
  }

  String _getDescriptionPrefix(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
      case PoiCategory.gallery:
        return 'The collection here tells us that';
      case PoiCategory.historicalSite:
      case PoiCategory.monument:
        return 'History records that';
      case PoiCategory.religiousSite:
        return 'The faithful here know that';
      case PoiCategory.park:
        return 'Nature enthusiasts appreciate that';
      case PoiCategory.university:
        return 'Scholars note that';
      case PoiCategory.theater:
        return 'Theater enthusiasts will appreciate that';
      case PoiCategory.architecture:
        return 'Architectural experts observe that';
      case PoiCategory.landmark:
      case PoiCategory.generic:
        return 'Interestingly,';
    }
  }

  String _getDescriptionSuffix(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
      case PoiCategory.gallery:
        return 'Take your time to absorb the exhibits.';
      case PoiCategory.historicalSite:
        return 'Imagine the stories these walls could tell!';
      case PoiCategory.religiousSite:
        return 'Please be respectful of worshippers.';
      case PoiCategory.park:
        return 'Enjoy the fresh air and scenery!';
      case PoiCategory.monument:
        return 'Take a moment to reflect on its significance.';
      case PoiCategory.university:
        return 'Knowledge has been cultivated here for generations.';
      case PoiCategory.theater:
        return 'The arts truly come alive in such venues!';
      case PoiCategory.architecture:
        return 'Notice the craftsmanship in every detail!';
      case PoiCategory.landmark:
      case PoiCategory.generic:
        return 'I hope you find this as fascinating as I do!';
    }
  }

  String _getContextualAddition(Poi poi, List<Poi>? nearbyPois) {
    if (nearbyPois == null || nearbyPois.isEmpty) {
      return '';
    }

    // Find POIs of the same category nearby
    final sameCategoryPois = nearbyPois
        .where((p) => p.id != poi.id && p.category == poi.category)
        .toList();

    if (sameCategoryPois.isNotEmpty) {
      final otherPoi = sameCategoryPois.first;
      return 'Fun fact: nearby you\'ll also find ${otherPoi.name}, '
          'which shares a similar theme with this location.';
    }

    // Find high interest POIs nearby
    final highInterestPois = nearbyPois
        .where(
            (p) => p.id != poi.id && p.interestLevel == PoiInterestLevel.high)
        .toList();

    if (highInterestPois.isNotEmpty) {
      final otherPoi = highInterestPois.first;
      return 'Pro tip: don\'t miss ${otherPoi.name} nearby - '
          'it\'s one of the highlights of this area!';
    }

    return '';
  }

  List<String> _getApproachTeasers(Poi poi) {
    final name = poi.name;
    final category = _getCategoryName(poi.category).toLowerCase();

    return [
      'Coming up ahead: $name! Get ready to discover this remarkable $category.',
      'We\'re approaching $name. This is going to be interesting!',
      'Just ahead is $name. Let me tell you about this fascinating place.',
      'Look up! $name awaits. This $category has quite a story to tell.',
      'Almost there! $name is just around the corner.',
    ];
  }
}
