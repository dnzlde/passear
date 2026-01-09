// lib/services/llm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Style for AI-generated stories
enum StoryStyle {
  neutral,
  humorous,
  forChildren,
}

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
          'LLM service is not properly configured. Please set up your API key in settings.');
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
    // Validate configuration
    if (!config.isValid) {
      throw LlmException(
          'LLM service is not properly configured. Please set up your API key in settings.');
    }

    final prompt = '''Based on the following POI information, determine if there is significantly more interesting and detailed content that could be shared beyond a basic tour story.

POI Name: $poiName
Description: $poiDescription

Consider:
- Historical significance and depth
- Architectural or artistic details
- Notable events or stories
- Cultural importance
- Unique or fascinating facts

Answer with ONLY "YES" or "NO" - nothing else.
YES if there's substantial additional interesting content (at least 2-3 more detailed aspects worth exploring).
NO if the landmark has limited notable features or the description covers most interesting aspects.''';

    try {
      final response = await _makeApiCall(prompt, maxTokens: contentCheckMaxTokens);
      final answer = response.trim().toUpperCase();
      return answer.startsWith('YES');
    } catch (e) {
      // If we can't determine, assume no additional content to avoid interruption
      debugPrint('Failed to check for more content: $e');
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
          'LLM service is not properly configured. Please set up your API key in settings.');
    }

    final prompt = '''You are an expert tour guide creating a detailed, engaging audio tour ${style.promptModifier}.

POI: $poiName
Description: $poiDescription

Previous story covered:
$originalStory

Create an EXTENDED story that:
- Dives deeper into fascinating details not covered in the basic story
- Length should match the significance: 5-8 paragraphs (400-700 words) for major landmarks with rich history, 3-4 paragraphs (250-400 words) for moderately significant sites
- Includes specific historical events, architectural details, cultural significance, or interesting anecdotes
- Maintains high content quality - every sentence should provide value
- Avoids generic introductions like "Welcome to..." or "Let me tell you about..." - start directly with interesting content
- Minimizes conclusions - end naturally with a compelling fact or observation
- Keeps the narrative engaging and original, not formulaic
- Focuses on what makes this place truly exceptional

Extended story:''';

    try {
      final response = await _makeApiCall(prompt, maxTokens: extendedStoryMaxTokens);

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
        {'role': 'user', 'content': prompt}
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
          'LLM API error (${response.statusCode}): $errorMessage');
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
