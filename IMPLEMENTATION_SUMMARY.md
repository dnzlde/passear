# POI Loading Timing Fix - Implementation Summary

## Problem Statement
The initial POI fetch was executed prematurely in `_initMap()` before the map had guaranteed valid bounds. A second fetch in `onMapReady` was throttled (2s window), so the useful post-layout fetch was skipped. Result: first launch often showed no POIs.

## Solution Implementation

### Key Changes Made

| **Aspect** | **Before (Broken)** | **After (Fixed)** |
|------------|-------------------|------------------|
| **Initial Load** | `_initMap()` calls `await _loadPoisInView()` prematurely | `_initMap()` only sets center/zoom, no POI loading |
| **Map Ready** | Simple `onMapReady: () => _loadPoisInView()` | Guarded with `_initialPoisLoaded` flag + `addPostFrameCallback` |
| **Throttling** | 2-second hard throttle blocks useful loads | 1-second throttle with `force` parameter to override |
| **Error Handling** | No bounds error handling | Try-catch with retry logic for bounds access |
| **Logging** | Used `print()` | Uses `debugPrint()` for better debugging |
| **Recenter** | `await _loadPoisInView()` (blocking) | `_loadPoisInView()` (non-blocking, standard throttle) |

### Code Comparison

#### Before (Problematic)
```dart
// ❌ PROBLEM: Premature POI loading with invalid bounds
Future<void> _initMap() async {
  final location = await _getCurrentLocation();
  if (location != null) {
    _mapCenter = location;
    _mapController.move(location, 15);
  }
  await _loadPoisInView(); // ❌ TOO EARLY!
}

// ❌ PROBLEM: No guard against duplicate loads  
onMapReady: () => _loadPoisInView(), // ❌ Often throttled!

// ❌ PROBLEM: Hard 2s throttle blocks useful requests
Future<void> _loadPoisInView() async {
  final now = DateTime.now();
  if (now.difference(_lastRequestTime).inSeconds < 2) return; // ❌ Too long!
  _lastRequestTime = now;
  final bounds = _mapController.camera.visibleBounds; // ❌ May fail!
  // ... rest of implementation
}
```

#### After (Fixed)
```dart
// ✅ SOLUTION: Only set map position, defer POI loading
Future<void> _initMap() async {
  // Only set initial center / zoom here. Do NOT load POIs yet.
  final location = await _getCurrentLocation();
  if (location != null) {
    _mapCenter = location;
    _mapController.move(location, 15);
  }
}

// ✅ SOLUTION: Guard flag ensures single initial load after layout
onMapReady: () {
  if (!_initialPoisLoaded) {
    _initialPoisLoaded = true;
    // Extra frame to ensure layout has occurred.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoisInView(force: true); // ✅ Override throttle for first load
    });
  }
},

// ✅ SOLUTION: Configurable throttle with force override and error handling
Future<void> _loadPoisInView({bool force = false}) async {
  final now = DateTime.now();
  const throttleSeconds = 1; // ✅ Faster response
  if (!force && now.difference(_lastRequestTime).inSeconds < throttleSeconds) return;
  _lastRequestTime = now;

  late final LatLngBounds bounds;
  try {
    bounds = _mapController.camera.visibleBounds;
  } catch (_) {
    // ✅ Graceful error handling with retry
    debugPrint('Bounds not ready yet, scheduling retry...');
    Future.delayed(const Duration(milliseconds: 120), () => _loadPoisInView(force: true));
    return;
  }
  // ... rest of implementation with debugPrint instead of print
}
```

## Acceptance Criteria Met

✅ **On cold start, POIs appear automatically once without user interaction**
- `_initialPoisLoaded` flag ensures exactly one initial load
- `addPostFrameCallback` ensures layout completion before API call

✅ **No double initial fetch**  
- Removed premature call from `_initMap()`
- Guard flag prevents duplicate `onMapReady` calls

✅ **Moving or zooming (gesture) still triggers fetch (subject to 1s throttle)**
- `onPositionChanged` unchanged, still calls `_loadPoisInView()`
- Reduced throttle from 2s to 1s for better responsiveness

✅ **Recenter button triggers a fetch (subject to throttle unless enough time elapsed)**
- `_centerToCurrentLocation()` calls standard `_loadPoisInView()` without `await`
- Subject to normal 1s throttling logic

## Testing Verification

The implementation can be verified through:

1. **Unit Tests**: Added in `test/map/poi_loading_timing_test.dart`
2. **Manual Testing**: Documented in `POI_LOADING_FIX_MANUAL_TEST.md`
3. **Debug Logging**: Enhanced logging shows the request sequence
4. **Integration Tests**: Existing tests continue to pass

## Impact Assessment

- **Minimal Code Changes**: Only essential modifications made to fix the timing issue
- **Backward Compatibility**: All existing functionality preserved
- **Performance Improvement**: Faster throttling (1s vs 2s) improves user experience
- **Reliability**: Error handling prevents crashes from premature bounds access
- **Debuggability**: Better logging helps diagnose future issues