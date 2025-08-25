# POI Startup Loading Fix - Verification Guide

## Issue Description
**Russian:** При запуске приложения надо триггерить первое обновление pois  
**English:** When starting the application, the first POI update should be triggered

## Problem
The original code had a timing issue where POIs were requested before the map was fully initialized:

```dart
Future<void> _initMap() async {
  final location = await _getCurrentLocation();
  if (location != null) {
    _mapCenter = location;
    _mapController.move(location, 15);
  }
  await _loadPoisInView(); // ❌ Called before map is ready!
}
```

This could cause:
- Map bounds not being available yet
- POI loading failing silently
- No POIs displayed on startup

## Solution
Removed the premature POI loading call and let the `onMapReady` callback handle initial POI loading:

```dart
Future<void> _initMap() async {
  final location = await _getCurrentLocation();
  if (location != null) {
    _mapCenter = location;
    _mapController.move(location, 15);
  }
  // ✅ POI loading will be triggered by onMapReady callback
  // to ensure map bounds are available
}
```

The `onMapReady: () => _loadPoisInView()` callback ensures POIs are loaded when the map is actually ready.

## Verification Steps

### Expected Behavior After Fix:
1. **App Startup**: User launches the Passear app
2. **Map Initialization**: Map loads with user's location (or fallback location)
3. **Map Ready Event**: `onMapReady` callback fires when map is fully initialized
4. **POI Loading**: `_loadPoisInView()` is called with valid map bounds
5. **POIs Display**: Points of interest appear on the map

### Testing the Fix:
1. Build and run the app: `flutter run`
2. Observe the startup sequence:
   - Map should load first
   - Loading indicator should appear briefly
   - POIs should appear once map is ready
3. No errors should appear in console related to invalid bounds

### Key Improvements:
- ✅ POIs are loaded when map is ready (not before)
- ✅ Error handling around map bounds access
- ✅ No timing-related crashes on startup
- ✅ First POI update is properly triggered

## Code Changes Summary

**File: `lib/map/map_page.dart`**
- Removed premature `await _loadPoisInView()` from `_initMap()`
- Added try-catch around map bounds access for safety
- Added explanatory comments

**File: `test/integration/poi_startup_test.dart`** (New)
- Added test to verify POI loading on app startup
- Simulates the initialization flow
- Ensures no crashes during startup sequence

This minimal change ensures the first POI update is triggered reliably when the application starts, addressing the original issue.