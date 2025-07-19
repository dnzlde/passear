# 🚶‍♂️ Passear

**Audio-First Sightseeing App**

Transform your walks into immersive audio tours! Passear (Portuguese for "to walk") is an innovative Flutter application that delivers location-aware audio content about nearby points of interest, creating a hands-free, eyes-up sightseeing experience.

## 🌟 Value Proposition

- **Hands-Free Exploration**: Listen to curated content about nearby landmarks while keeping your eyes on the world around you
- **Location-Aware**: Automatically discover points of interest based on your current location
- **Accessible Tourism**: Perfect for visually impaired users and anyone who prefers audio-guided experiences
- **Local Discovery**: Uncover hidden gems and learn fascinating stories about places you pass by every day

## ✨ Features

### Current Features
- 🗺️ **Interactive Map**: Real-time map display with POI markers
- 📍 **Location Services**: GPS-based location tracking and POI discovery
- 🔊 **Text-to-Speech**: High-quality audio narration of POI descriptions
- 📖 **Wikipedia Integration**: Rich content sourced from Wikipedia articles
- 🎯 **Proximity Detection**: Automatic POI loading based on your location
- 📱 **Cross-Platform**: Native Android and iOS support

### Planned Features (MVP)
- 🎵 **Audio Playlists**: Curated audio tours for popular routes
- 🏃‍♂️ **Walking Routes**: Guided walking tours with turn-by-turn audio
- ⬇️ **Offline Mode**: Download content for offline exploration
- 🎨 **Customizable Themes**: Personalize your app experience
- 🌐 **Multi-language Support**: Content in multiple languages

## 🛠️ Technology Stack

- **Framework**: [Flutter](https://flutter.dev/) - Cross-platform mobile development
- **Language**: [Dart](https://dart.dev/) - Modern, UI-focused programming language
- **Maps**: 
  - [Flutter Map](https://pub.dev/packages/flutter_map) - OpenStreetMap integration
  - [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter) - Google Maps support
- **Location Services**: [Geolocator](https://pub.dev/packages/geolocator) - GPS and location permissions
- **Audio**: [Flutter TTS](https://pub.dev/packages/flutter_tts) - Text-to-speech functionality
- **Data**: 
  - Local JSON storage for POI data
  - Wikipedia API integration
- **Coordinates**: [LatLong2](https://pub.dev/packages/latlong2) - Geographical coordinate handling

## 📦 Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.6.0 or higher)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) for device deployment
- A physical device or emulator for testing location services

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/dnzlde/passear.git
   cd passear
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Google Maps (Optional)**
   - Obtain a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
   - Add your API key to `google-maps-api-key` file (refer to existing file structure)

4. **Run the app**
   ```bash
   flutter run
   ```

## 🎯 Usage Guide

### For Users

1. **Grant Permissions**: Allow location access when prompted
2. **Explore the Map**: Pan and zoom to explore different areas
3. **Discover POIs**: Blue markers indicate points of interest
4. **Listen to Stories**: Tap on POI markers to hear audio descriptions
5. **Navigate**: Use your device's built-in navigation while listening

### Key Interactions
- **Tap POI Marker**: Open detailed view with audio playback
- **Pan Map**: Discover new POIs in different areas
- **Location Button**: Center map on your current location

## 💻 Development Setup

### Getting Started for Contributors

1. **Fork and Clone**
   ```bash
   git fork https://github.com/dnzlde/passear.git
   git clone https://github.com/YOUR_USERNAME/passear.git
   cd passear
   ```

2. **Development Environment**
   ```bash
   flutter doctor  # Check your Flutter installation
   flutter pub get  # Install dependencies
   flutter analyze  # Run static analysis
   ```

3. **Running Tests**
   ```bash
   flutter test  # Run unit tests
   ```

4. **Code Quality**
   ```bash
   flutter analyze  # Static analysis
   dart format .    # Code formatting
   ```

### Project Structure
```
lib/
├── main.dart           # App entry point
├── map/               # Map-related UI components
├── models/            # Data models (POI, etc.)
└── services/          # Business logic and API services
assets/
├── data/              # Local POI data
└── audio/             # Audio files
```

## 🗺️ Roadmap

### Phase 1: MVP (Current)
- [x] Basic map functionality
- [x] POI display and interaction
- [x] Text-to-speech integration
- [x] Location services
- [ ] Enhanced UI/UX polish
- [ ] Performance optimizations

### Phase 2: Enhanced Features
- [ ] Audio playlist creation
- [ ] Guided walking routes
- [ ] Offline content download
- [ ] User-generated content
- [ ] Social sharing features

### Phase 3: Advanced Features
- [ ] AR integration
- [ ] Machine learning recommendations
- [ ] Community features
- [ ] Professional tour guide tools
- [ ] Multi-language content

## 📸 Screenshots

*Screenshots and demo videos will be added here as the app develops*

<!-- Placeholder for screenshots -->
- Map View
- POI Detail View
- Audio Player Interface
- Settings Screen

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Types of Contributions
- 🐛 **Bug Reports**: Found an issue? Please report it!
- 💡 **Feature Requests**: Have ideas for new features?
- 🔧 **Code Contributions**: Submit pull requests for bug fixes or features
- 📖 **Documentation**: Help improve our docs and guides
- 🎵 **Content**: Contribute POI data and audio content

### Contributing Process
1. **Check Issues**: Look for existing issues or create a new one
2. **Fork & Branch**: Create a feature branch from `main`
3. **Code**: Follow our coding standards and write tests
4. **Test**: Ensure all tests pass and new features work correctly
5. **Submit PR**: Create a pull request with a clear description

### Code Style
- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Write tests for new features

### Reporting Issues
When reporting bugs, please include:
- Device information (OS, version)
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or logs if applicable

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses
This app uses several open-source packages. See individual package documentation for their respective licenses:
- Flutter (BSD-3-Clause)
- OpenStreetMap data (ODbL)
- Wikipedia content (CC BY-SA)

---

**Built with ❤️ using Flutter**

*Passear - Discover the world through sound*
