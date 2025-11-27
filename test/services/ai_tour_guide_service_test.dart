import 'package:flutter_test/flutter_test.dart';
import 'package:passear/services/ai_tour_guide_service.dart';
import 'package:passear/models/poi.dart';

void main() {
  group('AiTourGuideService', () {
    group('MockAiTourGuideService', () {
      late MockAiTourGuideService service;

      setUp(() {
        // Use zero delay for faster tests
        service = MockAiTourGuideService(
          simulatedDelay: Duration.zero,
        );
      });

      tearDown(() {
        service.dispose();
      });

      test('should initialize without errors', () {
        expect(() => MockAiTourGuideService(), returnsNormally);
      });

      test('should implement AiTourGuideService interface', () {
        expect(service, isA<AiTourGuideService>());
      });

      test('should always be available', () async {
        final isAvailable = await service.isAvailable();
        expect(isAvailable, true);
      });

      test('should generate narration for a POI', () async {
        final poi = Poi(
          id: 'test-1',
          name: 'Test Museum',
          lat: 40.7128,
          lon: -74.0060,
          description: 'A famous museum in the city.',
          audio: '',
          category: PoiCategory.museum,
          interestLevel: PoiInterestLevel.high,
        );

        final narration = await service.generateNarration(poi: poi);

        expect(narration, isNotEmpty);
        expect(narration, contains('Test Museum'));
        expect(narration, contains('museum'));
      });

      test('should generate different narrations for different categories',
          () async {
        final museumPoi = Poi(
          id: 'museum-1',
          name: 'Art Museum',
          lat: 40.7128,
          lon: -74.0060,
          description: 'Modern art collection.',
          audio: '',
          category: PoiCategory.museum,
          interestLevel: PoiInterestLevel.medium,
        );

        final parkPoi = Poi(
          id: 'park-1',
          name: 'Central Park',
          lat: 40.7829,
          lon: -73.9654,
          description: 'A large urban park.',
          audio: '',
          category: PoiCategory.park,
          interestLevel: PoiInterestLevel.high,
        );

        final museumNarration = await service.generateNarration(poi: museumPoi);
        final parkNarration = await service.generateNarration(poi: parkPoi);

        expect(museumNarration, isNot(equals(parkNarration)));
        expect(museumNarration.toLowerCase(), contains('museum'));
        expect(parkNarration.toLowerCase(),
            anyOf(contains('park'), contains('green'), contains('nature')));
      });

      test('should generate approach teaser', () async {
        final poi = Poi(
          id: 'test-2',
          name: 'Historic Cathedral',
          lat: 51.5074,
          lon: -0.1278,
          description: 'A historic cathedral.',
          audio: '',
          category: PoiCategory.religiousSite,
          interestLevel: PoiInterestLevel.high,
        );

        final teaser = await service.generateApproachTeaser(poi);

        expect(teaser, isNotEmpty);
        expect(teaser, contains('Historic Cathedral'));
      });

      test('should generate transition between POIs', () async {
        final fromPoi = Poi(
          id: 'from-1',
          name: 'Old Castle',
          lat: 51.5074,
          lon: -0.1278,
          description: 'An old medieval castle.',
          audio: '',
          category: PoiCategory.historicalSite,
          interestLevel: PoiInterestLevel.high,
        );

        final toPoi = Poi(
          id: 'to-1',
          name: 'Modern Gallery',
          lat: 51.5080,
          lon: -0.1280,
          description: 'A contemporary art gallery.',
          audio: '',
          category: PoiCategory.gallery,
          interestLevel: PoiInterestLevel.medium,
        );

        final transition = await service.generateTransition(
          fromPoi: fromPoi,
          toPoi: toPoi,
        );

        expect(transition, isNotEmpty);
        expect(transition, contains('Old Castle'));
        expect(transition, contains('Modern Gallery'));
      });

      test('should generate same-category transition', () async {
        final fromPoi = Poi(
          id: 'museum-1',
          name: 'Art Museum',
          lat: 40.7128,
          lon: -74.0060,
          description: 'Modern art collection.',
          audio: '',
          category: PoiCategory.museum,
          interestLevel: PoiInterestLevel.medium,
        );

        final toPoi = Poi(
          id: 'museum-2',
          name: 'History Museum',
          lat: 40.7130,
          lon: -74.0062,
          description: 'Historical artifacts.',
          audio: '',
          category: PoiCategory.museum,
          interestLevel: PoiInterestLevel.high,
        );

        final transition = await service.generateTransition(
          fromPoi: fromPoi,
          toPoi: toPoi,
        );

        expect(transition, isNotEmpty);
        expect(transition.toLowerCase(), contains('museum'));
        expect(transition, contains('History Museum'));
      });

      test('should include contextual information when nearby POIs provided',
          () async {
        final mainPoi = Poi(
          id: 'main-1',
          name: 'Main Attraction',
          lat: 40.7128,
          lon: -74.0060,
          description: 'The main attraction.',
          audio: '',
          category: PoiCategory.landmark,
          interestLevel: PoiInterestLevel.high,
        );

        final nearbyPoi = Poi(
          id: 'nearby-1',
          name: 'Nearby Landmark',
          lat: 40.7129,
          lon: -74.0061,
          description: 'A nearby landmark.',
          audio: '',
          category: PoiCategory.landmark,
          interestLevel: PoiInterestLevel.medium,
        );

        final narration = await service.generateNarration(
          poi: mainPoi,
          nearbyPois: [mainPoi, nearbyPoi],
        );

        expect(narration, isNotEmpty);
        // Should mention the main POI
        expect(narration, contains('Main Attraction'));
      });

      test('should handle POI with empty description', () async {
        final poi = Poi(
          id: 'empty-desc',
          name: 'Unknown Place',
          lat: 40.7128,
          lon: -74.0060,
          description: '',
          audio: '',
          category: PoiCategory.generic,
          interestLevel: PoiInterestLevel.low,
        );

        final narration = await service.generateNarration(poi: poi);

        expect(narration, isNotEmpty);
        expect(narration, contains('Unknown Place'));
      });

      test('should handle all POI categories', () async {
        for (final category in PoiCategory.values) {
          final poi = Poi(
            id: 'cat-${category.name}',
            name: 'Test ${category.name}',
            lat: 40.7128,
            lon: -74.0060,
            description: 'Description for ${category.name}',
            audio: '',
            category: category,
            interestLevel: PoiInterestLevel.medium,
          );

          final narration = await service.generateNarration(poi: poi);
          expect(narration, isNotEmpty, reason: 'Category: ${category.name}');
        }
      });

      test('should handle all interest levels', () async {
        for (final level in PoiInterestLevel.values) {
          final poi = Poi(
            id: 'level-${level.name}',
            name: 'Test ${level.name}',
            lat: 40.7128,
            lon: -74.0060,
            description: 'Description for ${level.name}',
            audio: '',
            category: PoiCategory.generic,
            interestLevel: level,
          );

          final narration = await service.generateNarration(poi: poi);
          expect(narration, isNotEmpty, reason: 'Level: ${level.name}');
        }
      });

      test('should truncate very long descriptions', () async {
        final longDescription = 'A' * 1000; // 1000 character description
        final poi = Poi(
          id: 'long-desc',
          name: 'Long Description POI',
          lat: 40.7128,
          lon: -74.0060,
          description: longDescription,
          audio: '',
          category: PoiCategory.museum,
          interestLevel: PoiInterestLevel.high,
        );

        final narration = await service.generateNarration(poi: poi);

        // Narration should be generated without error
        expect(narration, isNotEmpty);
        // Should not contain the full 1000 character description
        expect(narration.length, lessThan(longDescription.length + 500));
      });

      test('should dispose without errors', () async {
        await expectLater(service.dispose(), completes);
      });
    });
  });
}
