# Tour Audio Control Feature

## Overview
This feature allows users to control tour audio (POI descriptions and AI-generated stories) independently from navigation voice guidance. Users can now mute tour audio while still being able to read descriptions and receive navigation instructions.

## User Guide

### Accessing Audio Settings
1. Open the Passear app
2. Tap the settings (gear) icon
3. Scroll to the "Audio Settings" section

### Audio Controls
The "Audio Settings" section contains two independent toggles:

#### 1. Voice Guidance
- **Purpose**: Controls turn-by-turn navigation voice instructions
- **Icon**: Walking person (directions_walk)
- **Description**: "Enable voice instructions during navigation"
- **Default**: Enabled

#### 2. Tour Audio
- **Purpose**: Controls POI description audio and AI story playback
- **Icon**: Volume up (volume_up)
- **Description**: "Enable audio playback for POI descriptions"
- **Default**: Enabled

### Using Tour Audio

#### When Tour Audio is Enabled
1. **POI Descriptions**:
   - Tap any POI marker on the map
   - Tap the "Listen" button to play the description
   - Button changes to "Stop" (with red background) while audio is playing
   - Tap "Stop" to interrupt playback
   - Audio automatically stops when complete, button returns to "Listen" state

2. **AI-Generated Stories**:
   - Generate an AI story in the POI detail view
   - Audio plays automatically when story is generated
   - Use the "Play Again" button to replay the story
   - Audio respects the Tour Audio setting

#### When Tour Audio is Disabled
1. **Visual Indicator**:
   - Orange warning banner appears in POI detail view
   - Shows: "Tour audio is disabled" with mute icon

2. **Button States**:
   - "Listen" button shows "Audio Disabled"
   - Button is grayed out and cannot be tapped
   - "Play Again" button (AI stories) also shows "Audio Disabled"

3. **Reading Descriptions**:
   - All text descriptions remain fully readable
   - Only audio playback is affected

### Best Practices

**Enable Tour Audio when**:
- Walking alone and want hands-free experience
- Exploring a new area
- Using AI story features

**Disable Tour Audio when**:
- In a quiet environment (library, museum, etc.)
- Prefer reading over listening
- On a phone call or listening to music
- Conserving battery life

## Technical Documentation

### Architecture

#### Settings Model
Location: `lib/models/settings.dart`

```dart
class AppSettings {
  final bool tourAudioEnabled;
  // ... other fields
  
  AppSettings({
    this.tourAudioEnabled = true,
    // ... other parameters
  });
}
```

#### Settings Service
Location: `lib/services/settings_service.dart`

```dart
Future<void> updateTourAudioEnabled(bool enabled) async {
  final currentSettings = await loadSettings();
  final updatedSettings = currentSettings.copyWith(
    tourAudioEnabled: enabled,
  );
  await saveSettings(updatedSettings);
}
```

#### TTS Service Enhancement
Location: `lib/services/local_tts_service.dart`

New capabilities:
- `isPlaying` getter - tracks playback state
- `pause()` method - pauses playback
- `setCompletionCallback()` - notifies when audio completes
- Completion and error handlers properly initialized

### UI Components

#### Settings Page
Location: `lib/settings/settings_page.dart`

Changes:
- Renamed "Navigation Settings" to "Audio Settings"
- Added "Tour Audio" toggle with description
- Updated icon for voice guidance (more specific)
- Both settings in one card with divider separator

#### POI Detail View
Location: `lib/map/wiki_poi_detail.dart`

State Variables:
- `isPlayingAudio` - tracks current playback state
- `tourAudioEnabled` - cached setting value

Methods:
- `_loadTourAudioSetting()` - loads setting on init
- `_playAudio(String text)` - starts audio playback
- `_stopAudio()` - stops audio playback

UI Elements:
- Orange warning banner when audio disabled
- Listen/Stop button with state changes
- Disabled state for AI story playback

### Data Flow

```
User Toggle → SettingsService.updateTourAudioEnabled()
           → SharedPreferences (persisted)
           
App Start → SettingsService.loadSettings()
         → AppSettings.tourAudioEnabled
         → WikiPoiDetail._loadTourAudioSetting()

User Taps Listen → _playAudio() checks tourAudioEnabled
                 → TtsService.speak() or show disabled message
                 → TTS completion callback → UI updates
```

### Testing

#### Unit Tests
Location: `test/services/settings_service_test.dart`

Coverage:
- Default value verification (true)
- Setting persistence
- Setting isolation (doesn't affect other settings)
- Serialization/deserialization

#### Manual Testing
See `TOUR_AUDIO_FEATURE_TEST_PLAN.md` for comprehensive manual test scenarios

### Backward Compatibility

- **Default Value**: `true` (enabled)
- **Migration**: Existing users will have tour audio enabled by default
- **Storage**: Uses SharedPreferences with fallback to default value
- **No Breaking Changes**: All existing functionality preserved

### Performance Considerations

- Setting is loaded once on widget initialization
- Cached in widget state for fast access
- No performance impact when audio is disabled
- TTS handlers properly cleaned up on dispose

### Accessibility

- Clear visual indicators for audio state
- Descriptive button labels
- Settings descriptions explain functionality
- Works with screen readers (all buttons have semantic labels)

## Future Enhancements

Potential improvements for future versions:

1. **Pause/Resume**: Add pause button instead of just stop
2. **Speed Control**: Allow users to adjust TTS speech rate
3. **Auto-Play Toggle**: Option to automatically play POI audio when selected
4. **Audio History**: Track which POIs have been listened to
5. **Volume Control**: Independent volume slider for tour audio
6. **Audio Bookmarks**: Resume long descriptions from where you left off

## Troubleshooting

### Issue: Tour audio toggle doesn't save
**Solution**: Check app permissions for storage. Try force-closing and reopening the app.

### Issue: "Listen" button stays in "Stop" state
**Solution**: Audio may have failed to complete. Tap "Stop" manually or close and reopen the POI detail.

### Issue: No audio plays even when enabled
**Solution**: 
1. Check device volume
2. Ensure TTS is supported on your device
3. Check app audio permissions
4. Try a different POI

### Issue: AI Story doesn't respect audio setting
**Solution**: This is a known issue if LLM generates story before audio setting loads. Close and reopen the POI detail.

## Related Features

- **Voice Guidance**: Navigation turn-by-turn instructions (independent control)
- **AI Stories**: LLM-generated narrative content for POIs
- **POI Service**: Points of Interest discovery and description loading

## Credits

This feature was implemented to address user feedback requesting the ability to mute tour audio while preserving the ability to read descriptions. The design follows Flutter best practices and maintains consistency with the existing voice guidance toggle pattern.
