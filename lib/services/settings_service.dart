// lib/services/settings_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../models/poi.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';
  static SettingsService? _instance;

  SettingsService._();

  static SettingsService get instance => _instance ??= SettingsService._();

  AppSettings? _cachedSettings;

  /// Load settings from persistent storage
  Future<AppSettings> loadSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _cachedSettings = AppSettings.fromJson(settingsMap);
      } else {
        _cachedSettings = AppSettings(); // Use defaults
      }
    } catch (e) {
      // If loading fails, use default settings
      _cachedSettings = AppSettings();
    }

    return _cachedSettings!;
  }

  /// Save settings to persistent storage
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      _cachedSettings = settings;
    } catch (e) {
      // Handle save errors gracefully
      debugPrint('Failed to save settings: $e');
    }
  }

  /// Update a specific category setting
  Future<void> updateCategoryEnabled(PoiCategory category, bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedCategories = Map<PoiCategory, bool>.from(
      currentSettings.enabledCategories,
    );
    updatedCategories[category] = enabled;

    final updatedSettings = currentSettings.copyWith(
      enabledCategories: updatedCategories,
    );
    await saveSettings(updatedSettings);
  }

  /// Update max POI count
  Future<void> updateMaxPoiCount(int count) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(maxPoiCount: count);
    await saveSettings(updatedSettings);
  }

  /// Update voice guidance enabled setting
  Future<void> updateVoiceGuidanceEnabled(bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(
      voiceGuidanceEnabled: enabled,
    );
    await saveSettings(updatedSettings);
  }

  /// Update tour audio enabled setting
  Future<void> updateTourAudioEnabled(bool enabled) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(tourAudioEnabled: enabled);
    await saveSettings(updatedSettings);
  }

  /// Update map provider
  Future<void> updateMapProvider(MapProvider provider) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(mapProvider: provider);
    await saveSettings(updatedSettings);
  }

  /// Update routing provider
  Future<void> updateRoutingProvider(RoutingProvider provider) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(routingProvider: provider);
    await saveSettings(updatedSettings);
  }

  /// Update POI provider
  Future<void> updatePoiProvider(PoiProvider provider) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(poiProvider: provider);
    await saveSettings(updatedSettings);
  }

  /// Update LLM API key
  Future<void> updateLlmApiKey(String apiKey) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(llmApiKey: apiKey);
    await saveSettings(updatedSettings);
  }

  /// Update LLM API endpoint
  Future<void> updateLlmApiEndpoint(String apiEndpoint) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(
      llmApiEndpoint: apiEndpoint,
    );
    await saveSettings(updatedSettings);
  }

  /// Update LLM model
  Future<void> updateLlmModel(String model) async {
    final currentSettings = await loadSettings();
    final updatedSettings = currentSettings.copyWith(llmModel: model);
    await saveSettings(updatedSettings);
  }
}
