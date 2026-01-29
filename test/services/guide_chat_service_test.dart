import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:passear/services/guide_chat_service.dart';
import 'package:passear/services/poi_service.dart';
import 'package:passear/services/llm_service.dart';
import 'package:passear/models/poi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

/// Mock PoiService for testing
class MockPoiService extends PoiService {
  List<Poi>? _mockPois;

  void setMockPois(List<Poi> pois) {
    _mockPois = pois;
  }

  @override
  Future<List<Poi>> fetchNearby(
    double lat,
    double lon, {
    int radius = 1000,
  }) async {
    if (_mockPois != null) {
      return _mockPois!;
    }
    return super.fetchNearby(lat, lon, radius: radius);
  }

  @override
  Future<Poi> fetchPoiDescription(Poi poi) async {
    // Return the POI with a mock description
    return Poi(
      id: poi.id,
      name: poi.name,
      lat: poi.lat,
      lon: poi.lon,
      description: 'Mock description for ${poi.name}',
      audio: poi.audio,
      category: poi.category,
      interestScore: poi.interestScore,
      interestLevel: poi.interestLevel,
    );
  }
}

void main() {
  group('GuideChatService', () {
    late MockPoiService mockPoiService;
    late LlmService mockLlmService;
    late GuideChatService chatService;

    setUp(() {
      // Create mock HTTP client for LLM service
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        final messages = body['messages'] as List;
        final userMessage = messages.first['content'] as String;

        // Mock response based on query
        if (userMessage.contains('Nearby Points of Interest')) {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        'This is a mock response about nearby points of interest.',
                  },
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'error': {'message': 'Unknown request'},
          }),
          400,
        );
      });

      mockPoiService = MockPoiService();
      mockLlmService = LlmService(
        config: const LlmConfig(
          apiEndpoint: 'https://api.example.com/v1/chat/completions',
          apiKey: 'test-key',
          model: 'gpt-3.5-turbo',
        ),
        client: mockClient,
      );

      chatService = GuideChatService(
        poiService: mockPoiService,
        llmService: mockLlmService,
      );
    });

    test('getNearbyPois returns list of POIs', () async {
      final location = const LatLng(32.0741, 34.7924); // Tel Aviv

      // Configure mock to return a test POI
      final testPoi = Poi(
        id: 'test-poi-1',
        name: 'Test Location',
        lat: 32.0741,
        lon: 34.7924,
        description: 'A test point of interest',
        audio: '',
        category: PoiCategory.landmark,
        interestScore: 0.8,
        interestLevel: PoiInterestLevel.high,
      );
      mockPoiService.setMockPois([testPoi]);

      final pois = await chatService.getNearbyPois(location);
      expect(pois, isA<List<Poi>>());
      expect(pois.length, equals(1));
      expect(pois.first.name, equals('Test Location'));
    });

    test('askGuide throws exception when no POIs nearby', () async {
      // Configure mock to return empty list
      mockPoiService.setMockPois([]);

      final location = const LatLng(0.0, 0.0);

      expect(
        () => chatService.askGuide(
          question: 'What is nearby?',
          userLocation: location,
        ),
        throwsA(isA<GuideChatException>()),
      );
    });

    test('GuideChatException has correct message', () {
      final exception = GuideChatException('Test error message');

      expect(exception.message, equals('Test error message'));
      expect(exception.toString(), equals('Test error message'));
    });

    test('service uses correct search radius', () {
      expect(GuideChatService.searchRadiusMeters, equals(250));
    });

    test('service limits POIs in context correctly', () {
      expect(GuideChatService.maxPoisInContext, equals(5));
    });
  });
}
