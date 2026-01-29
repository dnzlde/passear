// test/services/llm_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passear/services/llm_service.dart';
import 'dart:convert';

void main() {
  group('LlmService', () {
    test('generates story successfully with valid API response', () async {
      final mockClient = MockClient((request) async {
        // Verify request headers - use contains to handle charset additions
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(request.headers['Authorization'], 'Bearer test-api-key');

        // Verify request body
        final body = jsonDecode(request.body);
        expect(body['model'], 'gpt-3.5-turbo');
        expect(body['messages'], isNotEmpty);

        // Return mock response
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      'This is an AI-generated story about the location.',
                },
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
        model: 'gpt-3.5-turbo',
      );

      final service = LlmService(config: config, client: mockClient);

      final story = await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(story, 'This is an AI-generated story about the location.');
    });

    test('throws LlmException when API key is invalid', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
          401,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'invalid-key',
      );

      final service = LlmService(config: config, client: mockClient);

      expect(
        () => service.generateStory(
          poiName: 'Test POI',
          poiDescription: 'A test description',
        ),
        throwsA(isA<LlmException>()),
      );
    });

    test('throws LlmException when API returns error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Server error'},
          }),
          500,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      expect(
        () => service.generateStory(
          poiName: 'Test POI',
          poiDescription: 'A test description',
        ),
        throwsA(isA<LlmException>()),
      );
    });

    test('throws LlmException when configuration is invalid', () async {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: '', // Empty API key
      );

      final service = LlmService(config: config);

      expect(
        () => service.generateStory(
          poiName: 'Test POI',
          poiDescription: 'A test description',
        ),
        throwsA(isA<LlmException>()),
      );
    });

    test('caches generated stories', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Cached story'},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      // First call - should hit the API
      await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      // Second call with same parameters - should use cache
      await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(callCount, 1); // API should only be called once
    });

    test('generates different stories for different styles', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        final prompt = body['messages'][0]['content'] as String;

        // Verify the prompt contains style-specific text
        String content;
        if (prompt.contains('with light humor')) {
          content = 'Humorous story';
        } else if (prompt.contains('for children')) {
          content = 'Child-friendly story';
        } else {
          content = 'Neutral story';
        }

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': content},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final neutralStory = await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        style: StoryStyle.neutral,
      );

      final humorousStory = await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        style: StoryStyle.humorous,
      );

      final childStory = await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        style: StoryStyle.forChildren,
      );

      expect(neutralStory, 'Neutral story');
      expect(humorousStory, 'Humorous story');
      expect(childStory, 'Child-friendly story');
    });

    test('clears cache when requested', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Story $callCount'},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      // First call
      await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      // Clear cache
      service.clearCache();

      // Second call - should hit API again after cache clear
      await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(callCount, 2); // API should be called twice
    });

    test('handles rate limit error correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Rate limit exceeded'},
          }),
          429,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      try {
        await service.generateStory(
          poiName: 'Test POI',
          poiDescription: 'A test description',
        );
        fail('Should have thrown LlmException');
      } catch (e) {
        expect(e, isA<LlmException>());
        expect(e.toString(), contains('Rate limit'));
      }
    });
  });

  group('LlmConfig', () {
    test('isValid returns true when properly configured', () {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      expect(config.isValid, true);
    });

    test('isValid returns false when API key is empty', () {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: '',
      );

      expect(config.isValid, false);
    });

    test('isValid returns false when endpoint is empty', () {
      final config = LlmConfig(apiEndpoint: '', apiKey: 'test-api-key');

      expect(config.isValid, false);
    });
  });

  group('StoryStyle', () {
    test('has correct display names', () {
      expect(StoryStyle.neutral.displayName, 'Neutral');
      expect(StoryStyle.humorous.displayName, 'With Humor');
      expect(StoryStyle.forChildren.displayName, 'For Children');
    });

    test('has correct prompt modifiers', () {
      expect(
        StoryStyle.neutral.promptModifier,
        contains('professional and informative'),
      );
      expect(StoryStyle.humorous.promptModifier, contains('light humor'));
      expect(StoryStyle.forChildren.promptModifier, contains('children'));
    });
  });

  group('hasMoreContent', () {
    test('returns true when API responds with YES', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'YES'},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final hasMore = await service.hasMoreContent(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(hasMore, true);
    });

    test('returns false when API responds with NO', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'NO'},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final hasMore = await service.hasMoreContent(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(hasMore, false);
    });

    test('returns false on error to avoid interruption', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final hasMore = await service.hasMoreContent(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(hasMore, false);
    });

    test('returns false when LLM is not configured', () async {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: '', // Invalid config
      );

      final service = LlmService(config: config);

      final hasMore = await service.hasMoreContent(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      expect(hasMore, false);
    });
  });

  group('generateExtendedStory', () {
    test('generates extended story successfully', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['max_tokens'], LlmService.extendedStoryMaxTokens);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      'This is a detailed extended story with much more information.',
                },
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final extendedStory = await service.generateExtendedStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        originalStory: 'Original story text',
      );

      expect(
        extendedStory,
        'This is a detailed extended story with much more information.',
      );
    });

    test('caches extended stories separately from regular stories', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Story $callCount'},
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      // Generate regular story
      await service.generateStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
      );

      // Generate extended story with same parameters - should call API again (different cache key)
      await service.generateExtendedStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        originalStory: 'Original',
      );

      // Second extended story call - should use cache
      await service.generateExtendedStory(
        poiName: 'Test POI',
        poiDescription: 'A test description',
        originalStory: 'Original',
      );

      expect(callCount, 2); // Regular story + extended story (cached)
    });

    test('throws LlmException when configuration is invalid', () async {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: '', // Empty API key
      );

      final service = LlmService(config: config);

      expect(
        () => service.generateExtendedStory(
          poiName: 'Test POI',
          poiDescription: 'A test description',
          originalStory: 'Original',
        ),
        throwsA(isA<LlmException>()),
      );
    });
  });

  group('chatWithGuide', () {
    test('generates chat response successfully', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        final messages = body['messages'] as List;
        final userMessage = messages.first['content'] as String;

        // Verify the prompt includes POI context
        expect(userMessage, contains('Nearby Points of Interest'));
        expect(userMessage, contains('User Question:'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      'This is a helpful response about the nearby POIs.',
                },
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final response = await service.chatWithGuide(
        userQuestion: 'What is interesting around here?',
        poisContext: [
          {
            'name': 'Test Museum',
            'description': 'A famous museum with ancient artifacts.',
          },
          {
            'name': 'Central Park',
            'description': 'A large public park in the city center.',
          },
        ],
      );

      expect(response, 'This is a helpful response about the nearby POIs.');
    });

    test('throws LlmException when configuration is invalid', () async {
      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: '', // Empty API key
      );

      final service = LlmService(config: config);

      expect(
        () => service.chatWithGuide(
          userQuestion: 'What is nearby?',
          poisContext: [],
        ),
        throwsA(isA<LlmException>()),
      );
    });

    test('handles empty POI context gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      'I don\'t have information about any nearby places.',
                },
              },
            ],
          }),
          200,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      final response = await service.chatWithGuide(
        userQuestion: 'What is nearby?',
        poisContext: [],
      );

      expect(response, contains('don\'t have information'));
    });

    test('throws LlmException on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'API error occurred'},
          }),
          500,
        );
      });

      final config = LlmConfig(
        apiEndpoint: 'https://api.example.com/chat/completions',
        apiKey: 'test-api-key',
      );

      final service = LlmService(config: config, client: mockClient);

      expect(
        () => service.chatWithGuide(
          userQuestion: 'What is nearby?',
          poisContext: [
            {'name': 'Test', 'description': 'Test'},
          ],
        ),
        throwsA(isA<LlmException>()),
      );
    });
  });
}
