# POI Loading Timing Fix - Manual Testing Guide

## Changes Made

The following changes were implemented to fix the POI loading timing issue:

1. **Added `_initialPoisLoaded` flag** - Guards against duplicate initial POI loads
2. **Removed premature POI loading** - Removed `await _loadPoisInView()` from `_initMap()`
3. **Added force parameter** - `_loadPoisInView({bool force = false})` can override throttling
4. **Enhanced onMapReady** - Uses `addPostFrameCallback` to ensure layout completion before loading POIs
5. **Reduced throttling** - Changed from 2 seconds to 1 second for better responsiveness
6. **Added bounds error handling** - Graceful retry if bounds are not ready
7. **Updated logging** - Changed `print` to `debugPrint`
8. **Fixed recenter behavior** - Removed `await` for standard throttled loading

## Expected Behavior

### ✅ Before This Fix (Problems)
- POIs often failed to load on first app launch
- Double API calls due to premature load + throttled onMapReady
- Invalid/tiny bounds used for initial API requests

### ✅ After This Fix (Solutions)
- POIs load exactly once after map is properly ready
- No duplicate initial fetches
- Valid bounds used for all API requests
- Faster user interaction (1s throttle vs 2s)

## Manual Testing Steps

### Test 1: Cold Start POI Loading
1. **Fresh Install**: Uninstall and reinstall the app
2. **Launch App**: Open the app for the first time
3. **Verify**: POIs should appear automatically without user interaction
4. **Check Logs**: Should see only one POI load request (unless retry needed)

### Test 2: Gesture-Based Loading
1. **Pan Map**: Drag the map to a new location
2. **Verify**: New POIs load after movement stops (1s throttle)
3. **Zoom**: Pinch to zoom in/out
4. **Verify**: POIs refresh based on new zoom level

### Test 3: Recenter Button
1. **Move Map**: Pan away from current location
2. **Tap Recenter**: Press the "my_location" floating action button
3. **Verify**: Map centers on current location and POIs refresh

### Test 4: No Double Loading
1. **Enable Debug Logging**: Watch console output
2. **Launch App**: Start the app
3. **Verify**: Only one initial POI load request should appear in logs
4. **Check**: No "throttled request" messages during initial load

### Test 5: Error Recovery
1. **Poor Network**: Test with slow/unstable internet
2. **Verify**: App handles bounds errors gracefully with retry logic
3. **Check**: App doesn't crash if initial bounds access fails

## Debug Verification

Look for these debug messages in the console:

- ✅ `"Bounds not ready yet, scheduling retry..."` - Only if very early timing issue
- ✅ `"Error loading POIs: ..."` - Only for actual network/API errors
- ❌ No duplicate POI loading messages during startup
- ❌ No throttling messages for the initial forced load

## Key Code Changes Summary

```dart
// New guard flag
bool _initialPoisLoaded = false;

// Enhanced onMapReady with proper timing
onMapReady: () {
  if (!_initialPoisLoaded) {
    _initialPoisLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoisInView(force: true);
    });
  }
},

// Force parameter to override throttling
Future<void> _loadPoisInView({bool force = false}) async {
  // 1s throttle with force override
  if (!force && now.difference(_lastRequestTime).inSeconds < 1) return;
  
  // Bounds error handling with retry
  try {
    bounds = _mapController.camera.visibleBounds;
  } catch (_) {
    debugPrint('Bounds not ready yet, scheduling retry...');
    Future.delayed(const Duration(milliseconds: 120), () => _loadPoisInView(force: true));
    return;
  }
}
```