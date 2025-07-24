# Mock API Client Implementation

## Overview
This implementation provides a mockable HTTP client architecture that solves the testing issues where real network requests to Wikipedia and OpenStreetMap APIs were being blocked by Flutter's test environment.

## Architecture

### 1. ApiClient Interface (`lib/services/api_client.dart`)
- **Abstract `ApiClient`**: Defines the contract for HTTP requests
- **`HttpApiClient`**: Production implementation using real HTTP requests
- **`MockApiClient`**: Test implementation with configurable responses

### 2. Updated Services
- **`WikipediaPoiService`**: Now accepts an `ApiClient` via dependency injection
- **`PoiService`**: Passes through the `ApiClient` to `WikipediaPoiService`
- **`MapPage`**: Uses default production implementation (no changes needed)

## Benefits

✅ **Fast Tests**: No network delays in test execution  
✅ **Deterministic**: Known, predictable responses for reliable testing  
✅ **CI/CD Ready**: Works reliably in automated environments  
✅ **Flutter Compliant**: Follows Flutter's testing best practices  

## Usage

### Production (Default)
```dart
// Uses real HTTP client automatically
final poiService = PoiService();
final pois = await poiService.fetchNearby(lat, lon);
```

### Testing with Mocks
```dart
// Use mock client for tests
final mockClient = MockApiClient();
final poiService = PoiService(apiClient: mockClient);

// Configure custom responses
mockClient.setWikipediaNearbyResponse('{"query": {"geosearch": [...]}}');

// Or use default mock responses
final pois = await poiService.fetchNearby(32.0741, 34.7924);
```

## Files Changed
- `lib/services/api_client.dart` (new)
- `lib/services/wikipedia_poi_service.dart` (minimal changes)
- `lib/services/poi_service.dart` (minimal changes)
- `test/services/api_client_test.dart` (new)
- `test/services/wikipedia_poi_service_test.dart` (new)
- `test/widget_test.dart` (updated with mock example)

## Demo
Run the demo to see the mock client in action:
```bash
dart example/test_mock_demo.dart
```

This implementation ensures tests no longer fail due to network request blocking while maintaining full production functionality.