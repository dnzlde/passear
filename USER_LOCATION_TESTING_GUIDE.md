# User Location Feature - Testing & Verification Guide

## Testing Checklist

### ✅ Prerequisites
- [ ] Flutter SDK installed
- [ ] Device/emulator with location services
- [ ] Location permissions granted to the app

### 🧪 Manual Testing Steps

#### 1. Initial Load Test
- [ ] Launch the Passear app
- [ ] Grant location permissions when prompted
- [ ] **Expected**: Map should center on your current location
- [ ] **Expected**: Blue circular marker should appear at your location
- [ ] **Expected**: No crashes or errors

#### 2. Location Marker Visibility Test
- [ ] Zoom in and out on the map
- [ ] **Expected**: User location marker stays at 60x60 size
- [ ] **Expected**: Marker remains visible at all zoom levels
- [ ] **Expected**: Marker is on top of POI markers

#### 3. Direction Indicator Test
- [ ] If device has compass: Rotate your device
- [ ] **Expected**: White arrow in the marker rotates with you
- [ ] **Expected**: Arrow points in the direction you're facing
- [ ] If no compass: Only circles should appear (no arrow)

#### 4. Movement Tracking Test
- [ ] Walk/move at least 5 meters
- [ ] **Expected**: Marker position updates to follow you
- [ ] Continue moving around
- [ ] **Expected**: Marker continues tracking your position

#### 5. Map Interaction Test
- [ ] Pan the map away from your location
- [ ] Tap "Center to my location" button (blue location icon)
- [ ] **Expected**: Map centers back on your location marker
- [ ] Rotate the map using two fingers
- [ ] **Expected**: User location marker maintains correct position

#### 6. POI Interaction Test
- [ ] Tap on a POI marker (not your location)
- [ ] **Expected**: POI details sheet opens
- [ ] **Expected**: Your location marker still visible in background
- [ ] Close the POI sheet
- [ ] **Expected**: User location marker unchanged

#### 7. Performance Test
- [ ] Use the app for 5-10 minutes
- [ ] Move around different areas
- [ ] **Expected**: No lag or stuttering
- [ ] **Expected**: Battery usage is reasonable
- [ ] **Expected**: Location updates smoothly

#### 8. Cleanup Test
- [ ] Close/kill the app
- [ ] Check device location settings
- [ ] **Expected**: No orphaned location tracking
- [ ] Reopen the app
- [ ] **Expected**: Location tracking starts fresh

### 🐛 Common Issues to Check

#### Issue: Location marker doesn't appear
- **Check**: Location permissions granted?
- **Check**: Location services enabled on device?
- **Check**: GPS signal available? (try going outside)

#### Issue: No direction arrow
- **Note**: This is normal if device has no compass
- **Check**: Some emulators don't support heading data
- **Try**: Use a real device with compass support

#### Issue: Marker position is inaccurate
- **Check**: GPS signal strength (walls/buildings can block)
- **Try**: Go outside for better GPS accuracy
- **Wait**: GPS accuracy improves after a few seconds

#### Issue: Marker doesn't update when moving
- **Check**: You've moved at least 5 meters (update threshold)
- **Check**: Location services still enabled
- **Try**: Force stop and restart the app

### 📱 Device-Specific Testing

#### iOS Devices
- [ ] Test on iOS simulator
- [ ] Test on physical iPhone
- [ ] Verify location permission dialog appears
- [ ] Test with "While Using App" permission

#### Android Devices
- [ ] Test on Android emulator
- [ ] Test on physical Android device
- [ ] Verify location permission dialog appears
- [ ] Test with different Android versions if possible

### 🔍 Visual Verification

Compare your marker with this description:
- **Outer circle**: Large, light blue, semi-transparent
- **Middle circle**: Medium blue with white border
- **Inner dot**: Small, solid blue
- **Arrow** (if available): White, points forward, rotates with heading

### 📊 Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| App launch | Marker appears at current location |
| Move 5+ meters | Marker follows your position |
| Rotate device | Arrow rotates (if compass available) |
| Zoom map | Marker stays fixed size |
| Pan map | Marker stays at GPS coordinates |
| Tap POI | Location marker remains visible |
| Close app | Location tracking stops cleanly |

### 🎯 Success Criteria

The feature is working correctly if:
1. ✅ Blue marker appears at your location on app launch
2. ✅ Marker updates position as you move
3. ✅ Direction arrow appears and rotates (on supported devices)
4. ✅ No crashes or performance issues
5. ✅ Marker is visually distinct from POI markers
6. ✅ Location tracking stops when app closes

### 🚀 Next Steps After Verification

If all tests pass:
- ✅ Feature is ready for production
- Consider adding to release notes
- Update app store screenshots

If issues found:
- Document specific problems
- Check console logs for errors
- Test on different devices/OS versions

### 📝 Build and Run Commands

```bash
# Clean build
flutter clean
flutter pub get

# Run on connected device/emulator
flutter run

# Run with verbose logging
flutter run -v

# Build for specific platform
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
```

### 🔧 Debugging Tips

Enable location logging:
```dart
// In map_page.dart _startLocationTracking():
_locationSubscription = Geolocator.getPositionStream(
  locationSettings: locationSettings,
).listen((Position position) {
  print('Location update: ${position.latitude}, ${position.longitude}');
  print('Heading: ${position.heading}');
  setState(() {
    _userLocation = LatLng(position.latitude, position.longitude);
    _userHeading = position.heading;
  });
});
```

Check console output for:
- Location permission status
- GPS accuracy
- Position updates frequency
- Any error messages

---

**Note**: Since this development was done without a Flutter environment, these tests should be performed on an actual device or emulator to fully verify the implementation.
