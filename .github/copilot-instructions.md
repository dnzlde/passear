# Copilot Instructions for Passear

Passear (Portuguese for "to walk") is a Flutter-based cross-platform mobile application that delivers location-aware audio content about nearby points of interest, creating a hands-free, eyes-up sightseeing experience.

## Technology Stack

- **Framework**: Flutter 3.x
- **Language**: Dart (SDK: >=3.6.0 <4.0.0)
- **Platform**: Android & iOS
- **Maps**: 
  - Flutter Map (OpenStreetMap)
  - Google Maps Flutter
- **Location**: Geolocator
- **Audio**: Flutter TTS, Just Audio
- **Storage**: Hive, Shared Preferences
- **Navigation**: Pedestrian routing with turn-by-turn voice guidance

## Code Standards

### Required Before Each Commit

1. **Format code**: Run `dart format .` before committing to ensure proper code formatting
2. **Static analysis**: Run `flutter analyze` to catch potential issues
3. **Run tests**: Execute `flutter test` to verify all tests pass
4. **CI validation**: Run `./validate_ci.sh` to ensure all CI checks will pass

### Development Flow

- **Install dependencies**: `flutter pub get`
- **Verify setup**: `flutter doctor -v`
- **Build**: `flutter run` (for development)
- **Test**: `flutter test` (runs all unit and widget tests)
- **Analyze**: `flutter analyze` (static code analysis)
- **Format**: `dart format .` (code formatting)
- **Full CI check**: `./validate_ci.sh` (runs all CI checks locally)

### Code Formatting

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format .` to automatically format code
- The CI pipeline enforces formatting with `dart format --set-exit-if-changed .`
- Do not commit unformatted code

## Repository Structure

```
lib/
├── main.dart           # App entry point
├── map/               # Map-related UI components
├── models/            # Data models (POI, Location, etc.)
├── services/          # Business logic and API services
└── settings/          # Settings management

test/
├── integration/       # Integration tests (POI startup, user location, lazy loading)
├── services/         # Service layer tests (TTS, API client, LLM, settings)
│   └── tts/          # TTS-specific tests (text splitter, Piper engine, models)

assets/
├── data/             # Local POI data (JSON)
└── audio/            # Audio files

.github/
├── workflows/        # CI/CD pipeline configuration
└── agents/           # Custom agent configurations
```

## Key Guidelines

1. **Follow Flutter/Dart best practices**: Use idiomatic Dart patterns and Flutter conventions
2. **Maintain existing code structure**: Keep the logical separation between UI (lib/map), models, and services
3. **Write tests for new functionality**: Add unit tests in `test/services/` and integration tests in `test/integration/`
4. **Use meaningful names**: Variable, function, and class names should be descriptive and follow Dart conventions
5. **Document complex logic**: Add comments for non-obvious implementations
6. **Location services**: Handle permissions properly and respect user privacy
7. **Audio features**: Ensure TTS and audio playback work correctly across platforms
8. **Map integration**: Test with both OpenStreetMap and Google Maps implementations
9. **Accessibility**: Maintain support for screen readers and voice navigation

## Testing

- **Unit tests**: Located in `test/services/` for service layer logic
- **Integration tests**: Located in `test/integration/` for end-to-end workflows
- **Widget tests**: Test UI components in isolation
- **Run all tests**: `flutter test`
- **Test naming**: Use `*_test.dart` suffix for all test files

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on:
- Push to `main` or `dev` branches
- Pull requests to `main`
- Manual workflow dispatch

**Automated checks**:
1. `flutter pub get` - Install dependencies
2. `flutter doctor -v` - Verify Flutter setup
3. `flutter analyze` - Static code analysis
4. `flutter test` - Run all tests
5. `dart format --set-exit-if-changed .` - Verify code formatting

**iOS builds**: Manual trigger only (requires Apple Developer account for device installation)

## Important Notes

- **Do not commit unformatted code**: Always run `dart format .` before committing
- **All tests must pass**: The CI will fail if any test fails or formatting is incorrect
- **Use the validation script**: Run `./validate_ci.sh` locally before pushing to catch issues early
- **Google Maps API key**: A placeholder key is included in the repository in the `google-maps-api-key` file. For production deployments, replace with your own API key and manage securely through environment variables or secret management
- **Location permissions**: Must be properly configured in Android and iOS manifests
- **Platform-specific code**: Test on both Android and iOS when making platform-specific changes

## Feature Areas

### Current Features
- Interactive map with POI markers
- Real-time GPS location tracking
- Text-to-speech audio narration
- Wikipedia API integration
- Pedestrian turn-by-turn navigation
- Voice guidance for navigation instructions
- Route planning to POIs or custom destinations

### Planned Features
- Audio playlists for curated tours
- Auto-rerouting when deviating from path
- Offline mode with downloaded content
- Multi-language support
- Customizable themes

## Accessibility

Passear is designed with accessibility in mind:
- Full screen reader support
- Voice-first navigation experience
- Audio descriptions for all UI elements
- Hands-free, eyes-up usage model
- Support for visually impaired users

## Performance Considerations

- **App size**: Target < 50MB
- **Memory efficiency**: Optimize for older devices
- **Battery usage**: Efficient GPS sampling and audio playback
- **Network usage**: Intelligent caching to reduce data consumption
- **UI smoothness**: Maintain 60 FPS for map interactions
