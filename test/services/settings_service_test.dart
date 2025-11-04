import 'package:flutter_test/flutter_test.dart';
import 'package:passear/models/settings.dart';
import 'package:passear/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({});
    });

    test('should load default settings when no settings are saved', () async {
      final settingsService = SettingsService.instance;
      final settings = await settingsService.loadSettings();

      expect(settings.voiceGuidanceEnabled, true);
      expect(settings.maxPoiCount, 20);
    });

    test('should save and load voice guidance setting', () async {
      final settingsService = SettingsService.instance;
      
      // Update voice guidance setting
      await settingsService.updateVoiceGuidanceEnabled(false);

      // Load settings and verify
      final settings = await settingsService.loadSettings();
      expect(settings.voiceGuidanceEnabled, false);
    });

    test('should update voice guidance setting without affecting other settings',
        () async {
      final settingsService = SettingsService.instance;
      
      // Set initial state
      await settingsService.updateMaxPoiCount(30);
      await settingsService.updateVoiceGuidanceEnabled(true);

      // Update only voice guidance
      await settingsService.updateVoiceGuidanceEnabled(false);

      // Verify both settings
      final settings = await settingsService.loadSettings();
      expect(settings.voiceGuidanceEnabled, false);
      expect(settings.maxPoiCount, 30);
    });

    test('should serialize and deserialize voice guidance setting correctly',
        () async {
      final settingsService = SettingsService.instance;
      final originalSettings = AppSettings(
        voiceGuidanceEnabled: false,
        maxPoiCount: 25,
      );

      // Save settings
      await settingsService.saveSettings(originalSettings);

      // Reload from storage
      final loadedSettings = await settingsService.loadSettings();

      expect(loadedSettings.voiceGuidanceEnabled, false);
      expect(loadedSettings.maxPoiCount, 25);
    });

    test('AppSettings should have correct default for voiceGuidanceEnabled',
        () {
      final settings = AppSettings();
      expect(settings.voiceGuidanceEnabled, true);
    });

    test('AppSettings copyWith should work correctly for voiceGuidanceEnabled',
        () {
      final settings = AppSettings(voiceGuidanceEnabled: true);
      final updated = settings.copyWith(voiceGuidanceEnabled: false);

      expect(updated.voiceGuidanceEnabled, false);
      expect(settings.voiceGuidanceEnabled, true); // Original unchanged
    });

    test('AppSettings toJson and fromJson should preserve voiceGuidanceEnabled',
        () {
      final original = AppSettings(voiceGuidanceEnabled: false, maxPoiCount: 30);
      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.voiceGuidanceEnabled, false);
      expect(restored.maxPoiCount, 30);
    });
  });
}
