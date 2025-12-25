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

  /// Build the prompt for the LLM
  String _buildPrompt(String poiName, String poiDescription, StoryStyle style) {
    return '''You are an expert tour guide. Create an engaging audio tour story about "$poiName" ${style.promptModifier}.

Based on the following information:
$poiDescription

Generate a compelling 2-3 paragraph story that:
- Is suitable for text-to-speech
- Highlights the most interesting aspects
- Engages the listener
- Is concise but informative (around 150-200 words)
- When possible, includes information about the time period and circumstances of its creation or establishment

Story:''';
  }

  /// Make the API call to the LLM service
  Future<String> _makeApiCall(String prompt) async {
    final uri = Uri.parse(config.apiEndpoint);

    final requestBody = {
      'model': config.model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.7,
      'max_tokens': 300,
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
