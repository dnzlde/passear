# Cancellable HTTP Requests Implementation

## Overview
This implementation adds support for cancellable HTTP requests to the ApiClient, enabling the application to cancel outdated POI requests when the user moves the map viewport.

## Key Components

### 1. ApiCancellationToken
- Simple boolean flag-based cancellation token
- Methods: `cancel()`, `reset()`, `isCancelled` getter
- Similar to the existing TTS CancellationToken pattern

### 2. ApiClient Interface
- Added optional `cancelToken` parameter to `get()` and `post()` methods
- Maintains backward compatibility (parameter is optional)

### 3. HttpApiClient Implementation
- Creates dedicated HTTP clients for cancellable requests
- Checks cancellation before and after HTTP operations
- Properly closes HTTP clients to prevent resource leaks
- Throws `ApiRequestCancelledException` when cancelled

### 4. MockApiClient Implementation
- Supports cancellation for testing purposes
- Checks cancellation token immediately before processing

### 5. Service Layer Integration

#### OverpassPoiService
- Propagates cancel token to API client
- Checks cancellation in retry logic to avoid unnecessary retries
- Throws ApiRequestCancelledException immediately on cancellation

#### WikipediaPoiService
- Propagates cancel token through `fetchIntelligentPoisInBounds()`
- Propagates through `fetchPoisInBounds()` and `fetchNearbyPois()`

#### PoiService
- Passes cancel token to cache service fetch function
- Propagates through both Wikipedia and Overpass providers

### 6. MapPage Integration
- Tracks current POI request with `_currentPoiRequest` field
- Cancels previous request when `_loadPoisInView()` is called
- Creates new cancellation token for each viewport load
- Silently handles `ApiRequestCancelledException` (expected behavior)

## Benefits

1. **Performance**: Avoids wasting resources on outdated requests
2. **Responsiveness**: Faster map interactions when user moves quickly
3. **Resource Management**: No leaked pending HTTP operations
4. **Clean Architecture**: Uses existing patterns (similar to TTS cancellation)

## Testing

### Unit Tests (test/services/api_client_test.dart)
- ApiCancellationToken lifecycle (create, cancel, reset)
- Basic cancellation before request
- Successful requests with non-cancelled tokens

### Race Condition Tests (test/services/api_client_cancellation_test.dart)
- Cancel during async request execution
- Multiple rapid cancellations
- Response processing during cancellation
- Memory leak detection (no accumulated pending operations)
- Concurrent request isolation (cancelling one doesn't affect others)

### Integration Tests (test/services/poi_service_cancellation_test.dart)
- OverpassPoiService cancellation propagation
- WikipediaPoiService cancellation propagation
- Viewport change scenarios (simulating real usage)
- Rapid viewport changes (stress testing)
- Memory leak detection at service level

## Acceptance Criteria (Met)

✅ **Outdated requests are actually cancelled**: HTTP clients are closed, not just results ignored
✅ **No leaked pending operations**: Dedicated clients are properly closed in finally blocks
✅ **Tests for cancel-before-response**: Covered in api_client_test.dart
✅ **Tests for cancel-race**: Comprehensive scenarios in api_client_cancellation_test.dart
✅ **Integration with viewport changes**: MapPage properly cancels on viewport movement

## Usage Example

```dart
// In MapPage
ApiCancellationToken? _currentPoiRequest;

Future<void> _loadPoisInView() async {
  // Cancel previous request
  _currentPoiRequest?.cancel();
  _currentPoiRequest = ApiCancellationToken();
  
  try {
    final pois = await _poiService.fetchInBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
      cancelToken: _currentPoiRequest,
    );
    // Use pois...
  } on ApiRequestCancelledException {
    // Request was cancelled - this is expected
  }
}
```

## Future Improvements
- Consider timeouts with cancellation
- Add metrics for cancelled requests
- Potential optimization: cancel at tile fetch level in cache service
