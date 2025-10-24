# Routing Architecture

This document explains the routing abstraction layer and how to add or switch routing providers.

## Architecture Overview

The routing system uses a provider pattern with three main components:

1. **RoutingProvider** (Interface) - Abstract interface that all routing providers must implement
2. **Concrete Providers** - Specific implementations (OSRM, Google Maps, etc.)
3. **RoutingService** (Facade) - Main service that manages providers and fallback logic

```
┌─────────────────────────────────────────┐
│         RoutingService                  │
│  (Facade with fallback management)      │
└───────────────┬─────────────────────────┘
                │
                │ uses
                │
        ┌───────▼───────────────────────┐
        │   RoutingProvider             │
        │   (Abstract Interface)        │
        └───────┬───────────────────────┘
                │
                │ implemented by
                │
    ┌───────────┴───────────┬───────────────────┐
    │                       │                   │
┌───▼────────────┐  ┌──────▼──────────┐  ┌────▼─────────┐
│ OSRM Provider  │  │ Fallback Provider│  │  Future:     │
│ (Default)      │  │ (Offline)        │  │  Google Maps │
└────────────────┘  └──────────────────┘  │  OpenRoute   │
                                          └──────────────┘
```

## Components

### 1. RoutingProvider Interface

Located in `lib/services/routing_provider.dart`

```dart
abstract class RoutingProvider {
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  });
  
  String get providerName;
  bool get requiresApiKey;
}
```

### 2. Concrete Providers

#### OsrmRoutingProvider
- **File**: `lib/services/osrm_routing_provider.dart`
- **Provider**: OSRM (Open Source Routing Machine)
- **API Key**: Not required
- **Features**: 
  - Uses OpenStreetMap data
  - Free public API
  - Turn-by-turn instructions
  - Real street names

#### FallbackRoutingProvider
- **File**: `lib/services/fallback_routing_provider.dart`
- **Provider**: Simple fallback (straight line)
- **API Key**: Not required
- **Features**:
  - Works offline
  - No external dependencies
  - Straight-line routing
  - Basic distance/time estimates

### 3. RoutingService (Facade)

Located in `lib/services/routing_service.dart`

The main service that:
- Manages primary and fallback providers
- Automatically falls back on errors
- Provides a consistent API to the rest of the app
- Logs which provider is being used

## Usage

### Basic Usage (Default)

```dart
// Uses OSRM as primary, fallback as backup
final routingService = RoutingService();

final route = await routingService.getRoute(
  start: LatLng(32.0741, 34.7924),
  destination: LatLng(32.0751, 34.7934),
);
```

### Custom Provider Configuration

```dart
// Use a specific provider
final customProvider = OsrmRoutingProvider();
final routingService = RoutingService(
  primaryProvider: customProvider,
);
```

### Multiple Providers with Fallback

```dart
// Primary: OSRM, Fallback: Straight line
final routingService = RoutingService(
  primaryProvider: OsrmRoutingProvider(),
  fallbackProvider: FallbackRoutingProvider(),
);
```

## Adding a New Provider

To add a new routing provider (e.g., Google Maps, OpenRouteService):

### Step 1: Create Provider Class

Create `lib/services/your_provider_routing_provider.dart`:

```dart
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import 'routing_provider.dart';

class YourProviderRoutingProvider implements RoutingProvider {
  @override
  String get providerName => 'YourProvider';

  @override
  bool get requiresApiKey => true; // or false

  @override
  Future<NavigationRoute?> getRoute({
    required LatLng start,
    required LatLng destination,
  }) async {
    // Your implementation here
    // 1. Make API call
    // 2. Parse response
    // 3. Return NavigationRoute
    // 4. Return null on error
  }
}
```

### Step 2: Implement API Call

```dart
@override
Future<NavigationRoute?> getRoute({
  required LatLng start,
  required LatLng destination,
}) async {
  try {
    // Build API URL
    final url = Uri.https('your-api.com', '/route', {
      'start': '${start.latitude},${start.longitude}',
      'end': '${destination.latitude},${destination.longitude}',
      // Add your API key if needed
    });

    // Make request
    final response = await _apiClient.get(url);
    final data = json.decode(response);

    // Parse and return route
    return _parseRoute(data);
  } catch (e) {
    debugPrint('Error with YourProvider: $e');
    return null;
  }
}
```

### Step 3: Parse Response

```dart
NavigationRoute _parseRoute(Map<String, dynamic> data) {
  // Extract waypoints (route geometry)
  final waypoints = _parseWaypoints(data['geometry']);
  
  // Extract turn-by-turn instructions
  final instructions = _parseInstructions(data['steps']);
  
  return NavigationRoute(
    waypoints: waypoints,
    distanceMeters: data['distance'].toDouble(),
    durationSeconds: data['duration'].toDouble(),
    instructions: instructions,
  );
}
```

### Step 4: Use Your Provider

```dart
// In your app
final routingService = RoutingService(
  primaryProvider: YourProviderRoutingProvider(),
  fallbackProvider: OsrmRoutingProvider(), // or FallbackRoutingProvider()
);
```

## Switching Providers

You can easily switch between providers:

### At App Startup

```dart
// In main.dart or where you initialize services
final RoutingService routingService;

if (useGoogleMaps) {
  routingService = RoutingService(
    primaryProvider: GoogleMapsRoutingProvider(),
  );
} else {
  routingService = RoutingService(
    primaryProvider: OsrmRoutingProvider(),
  );
}
```

### Based on Settings

```dart
RoutingService createRoutingService(RoutingProvider provider) {
  switch (provider) {
    case RoutingProvider.OSRM:
      return RoutingService(
        primaryProvider: OsrmRoutingProvider(),
      );
    case RoutingProvider.GoogleMaps:
      return RoutingService(
        primaryProvider: GoogleMapsRoutingProvider(),
      );
    default:
      return RoutingService(); // Default (OSRM)
  }
}
```

### Dynamic Switching

```dart
class NavigationManager {
  RoutingService _routingService;

  void switchProvider(RoutingProvider newProvider) {
    _routingService = RoutingService(
      primaryProvider: newProvider,
    );
  }
}
```

## Provider Comparison

| Provider | API Key | Cost | Coverage | Quality | Offline |
|----------|---------|------|----------|---------|---------|
| OSRM | No | Free | Global | Good | No |
| Fallback | No | Free | Global | Basic | Yes |
| Google Maps* | Yes | Paid | Global | Excellent | No |
| OpenRoute* | Yes | Free tier | Global | Good | No |

*Future providers (not yet implemented)

## Testing

When testing, you can inject a mock provider:

```dart
// In tests
final mockProvider = MockRoutingProvider();
when(mockProvider.getRoute(any, any))
    .thenAnswer((_) async => testRoute);

final service = RoutingService(
  primaryProvider: mockProvider,
);
```

## Best Practices

1. **Always use RoutingService, not providers directly** - This ensures fallback behavior
2. **Handle null returns** - Providers may return null on errors
3. **Log provider usage** - RoutingService already does this with debugPrint
4. **Test fallback scenarios** - Ensure your app works when primary provider fails
5. **Consider API quotas** - Some providers have rate limits

## Future Enhancements

Planned improvements:

- [ ] Settings UI to choose routing provider
- [ ] Multiple fallback providers (chain of responsibility)
- [ ] Route caching to reduce API calls
- [ ] Provider-specific settings (API keys, preferences)
- [ ] A/B testing different providers
- [ ] Performance metrics per provider
