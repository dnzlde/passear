// lib/services/llm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Style for AI-generated stories
enum StoryStyle { neutral, humorous, forChildren }

extension StoryStyleExtension on StoryStyle {
  String get displayName {
    switch (this) {
      case StoryStyle.neutral:
        return 'Neutral';
      case StoryStyle.humorous:
        return 'With Humor';
      case StoryStyle.forChildren:
        return 'For Children';
    }
  }

  String get description {
    switch (this) {
      case StoryStyle.neutral:
        return 'Professional and informative';
      case StoryStyle.humorous:
        return 'Engaging with light humor';
      case StoryStyle.forChildren:
        return 'Simple and fun for kids';
    }
  }

  String get promptModifier {
    switch (this) {
      case StoryStyle.neutral:
        return 'in a professional and informative tone';
      case StoryStyle.humorous:
        return 'with light humor and engaging storytelling';
      case StoryStyle.forChildren:
        return 'in simple language suitable for children, making it fun and easy to understand';
    }
  }
}

/// Configuration for LLM API
class LlmConfig {
  final String apiEndpoint;
  final String apiKey;
  final String model;

  const LlmConfig({
    required this.apiEndpoint,
    required this.apiKey,
    this.model = 'gpt-3.5-turbo',
  });

  /// Check if the configuration is valid
  bool get isValid => apiKey.isNotEmpty && apiEndpoint.isNotEmpty;
}

/// Service for generating AI stories using LLM
class LlmService {
  final LlmConfig config;
  final http.Client? _client;
  final Map<String, String> _storyCache = {};

  // Constants for max tokens
  static const int standardStoryMaxTokens = 600;
  static const int extendedStoryMaxTokens = 1200;
  static const int contentCheckMaxTokens = 20;

  LlmService({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  /// Generate an AI story for a POI
  Future<String> generateStory({
    required String poiName,
    required String poiDescription,
    StoryStyle style = StoryStyle.neutral,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(poiName, poiDescription, style);
    if (_storyCache.containsKey(cacheKey)) {
      return _storyCache[cacheKey]!;
    }

    // Validate configuration
    if (!config.isValid) {
      throw LlmException(
        'LLM service is not properly configured. Please set up your API key in settings.',
      );
    }

    // Build the prompt
    final prompt = _buildPrompt(poiName, poiDescription, style);

    try {
      final response = await _makeApiCall(prompt);

      // Cache the result
      _storyCache[cacheKey] = response;

      return response;
    } catch (e) {
      throw LlmException('Failed to generate AI story: $e');
    }
  }

  /// Check if there's significantly more interesting information available for this POI
  Future<bool> hasMoreContent({
    required String poiName,
    required String poiDescription,
  }) async {
    // Validate configuration - return false instead of throwing to avoid interruption
    if (!config.isValid) {
      debugPrint('hasMoreContent: LLM not configured, returning false');
      return false;
    }

    final prompt =
        '''Based on the following POI information, determine if there is SUBSTANTIALLY MORE fascinating and unique content that would make an extended tour genuinely interesting and valuable.

POI Name: $poiName
Description: $poiDescription

CRITICAL: Answer YES ONLY if you can provide:
- Multiple (3+) compelling additional facts, stories, or details NOT in the description
- Specific historical events, architectural secrets, or cultural insights
- Unique anecdotes or lesser-known information that would fascinate visitors
- Content that is INTERESTING, not generic filler or repetition

Answer with ONLY "YES" or "NO" - nothing else.
YES = Substantial fascinating additional content available (worthy of an extended tour)
NO = Limited additional content, or information would be generic/repetitive (no extended tour needed)

Be STRICT: When in doubt, answer NO. Quality over quantity.''';

    try {
      debugPrint('hasMoreContent: Checking content for POI: $poiName');
      final response = await _makeApiCall(
        prompt,
        maxTokens: contentCheckMaxTokens,
      );
      final answer = response.trim().toUpperCase();
      debugPrint('hasMoreContent: LLM response: "$answer"');
      final result = answer.startsWith('YES');
      debugPrint('hasMoreContent: Returning $result for $poiName');
      return result;
    } catch (e) {
      // If we can't determine, assume no additional content to avoid interruption
      debugPrint('hasMoreContent: Failed to check for more content: $e');
      return false;
    }
  }

  /// Generate an extended story with more details
  Future<String> generateExtendedStory({
    required String poiName,
    required String poiDescription,
    required String originalStory,
    StoryStyle style = StoryStyle.neutral,
  }) async {
    // Check cache first
    final cacheKey = '${_getCacheKey(poiName, poiDescription, style)}_extended';
    if (_storyCache.containsKey(cacheKey)) {
      return _storyCache[cacheKey]!;
    }

    // Validate configuration
    if (!config.isValid) {
      throw LlmException(
        'LLM service is not properly configured. Please set up your API key in settings.',
      );
    }

    final prompt =
        '''You are an expert tour guide creating a detailed, engaging audio tour ${style.promptModifier}.

POI: $poiName
Description: $poiDescription

Previous story covered:
$originalStory

CRITICAL REQUIREMENTS for the EXTENDED story:
- Do NOT repeat ANY information from the previous story
- Share ONLY new, fascinating details not mentioned before
- Include specific facts: dates, names, events, architectural details, cultural significance
- Every sentence must provide NEW VALUE - no generic statements or filler
- Length: 5-8 paragraphs (400-700 words) for major landmarks, 3-4 paragraphs (250-400 words) for moderate sites
- Start directly with interesting new content - NO introductions like "Let me tell you more..."
- End naturally with a compelling new fact - NO generic conclusions

QUALITY CHECK: If you find yourself repeating the previous story or adding generic filler, STOP.
Only continue if you have genuinely interesting NEW information.

Extended story with NEW fascinating details:''';

    try {
      final response = await _makeApiCall(
        prompt,
        maxTokens: extendedStoryMaxTokens,
      );

      // Cache the result
      _storyCache[cacheKey] = response;

      return response;
    } catch (e) {
      throw LlmException('Failed to generate extended story: $e');
    }
  }

  /// Build the prompt for the LLM
  String _buildPrompt(String poiName, String poiDescription, StoryStyle style) {
    return '''You are an expert tour guide. Create an engaging audio tour story about "$poiName" ${style.promptModifier}.

Based on the following information:
$poiDescription

Generate a compelling story that:
- Is suitable for text-to-speech
- Highlights only the most interesting and significant aspects
- Engages the listener with quality content, avoiding filler or repetitive information
- Should be 3-5 paragraphs if there is rich content (250-400 words), but can be shorter (2-3 paragraphs) if the landmark has limited notable features - quality over quantity
- When possible, includes information about the time period and circumstances of its creation or establishment
- Focuses on what makes this place truly special and worth visiting

Story:''';
  }

  /// Make the API call to the LLM service
  Future<String> _makeApiCall(String prompt, {int? maxTokens}) async {
    final uri = Uri.parse(config.apiEndpoint);

    final requestBody = {
      'model': config.model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': maxTokens ?? standardStoryMaxTokens,
    };

    final response = await _client!.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Handle OpenAI-compatible response format
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        final message = data['choices'][0]['message'];
        if (message != null && message['content'] != null) {
          return (message['content'] as String).trim();
        }
      }

      throw LlmException('Unexpected response format from LLM API');
    } else if (response.statusCode == 401) {
      throw LlmException('Invalid API key. Please check your LLM settings.');
    } else if (response.statusCode == 429) {
      throw LlmException('Rate limit exceeded. Please try again later.');
    } else {
      final errorMessage = _extractErrorMessage(response.body);
      throw LlmException(
        'LLM API error (${response.statusCode}): $errorMessage',
      );
    }
  }

  /// Extract error message from API response
  String _extractErrorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data['error'] != null) {
        if (data['error']['message'] != null) {
          return data['error']['message'];
        }
        return data['error'].toString();
      }
    } catch (e) {
      debugPrint('Failed to parse error response: $e');
    }
    return 'Unknown error';
  }

  /// Generate cache key for a story
  String _getCacheKey(String poiName, String poiDescription, StoryStyle style) {
    return '${poiName}_${poiDescription.hashCode}_${style.name}';
  }

  /// Chat with AI guide about nearby POIs
  /// Returns a response based on the provided POI context and user question
  Future<String> chatWithGuide({
    required String userQuestion,
    required List<Map<String, String>> poisContext,
  }) async {
    // Validate configuration
    if (!config.isValid) {
      throw LlmException(
        'LLM service is not properly configured. Please set up your API key in settings.',
      );
    }

    // Build context from nearby POIs
    final contextBuilder = StringBuffer();
    contextBuilder.writeln('Nearby Points of Interest:');
    contextBuilder.writeln();

    for (var i = 0; i < poisContext.length; i++) {
      final poi = poisContext[i];
      contextBuilder.writeln('${i + 1}. ${poi['name']}');
      if (poi['description'] != null && poi['description']!.isNotEmpty) {
        contextBuilder.writeln('   ${poi['description']}');
      }
      contextBuilder.writeln();
    }

    // Build the prompt
    final prompt =
        '''You are a knowledgeable tour guide assistant. Answer the user's question based ONLY on the information provided about nearby points of interest. If the answer cannot be found in the provided context, politely say you don't have that information.

$contextBuilder

User Question: $userQuestion

Provide a helpful, concise answer (2-3 paragraphs maximum) based on the available information:''';

    try {
      return await _makeApiCall(prompt, maxTokens: 400);
    } catch (e) {
      throw LlmException('Failed to get guide response: $e');
    }
  }

  /// Clear the story cache
  void clearCache() {
    _storyCache.clear();
  }

  /// Dispose of resources
  void dispose() {
    _client?.close();
  }
}

/// Exception thrown by LLM service
class LlmException implements Exception {
  final String message;

  LlmException(this.message);

  @override
  String toString() => message;
}
