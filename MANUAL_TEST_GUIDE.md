# Manual Testing Guide for POI Details Widget

## POI Details Widget Tap-Outside Dismissal Fix

### Test Case: POI Modal Dismissal Functionality

#### Prerequisites
- Flutter app should be running on a device or emulator
- App should have access to POI data or use mock POI data
- Map should be loaded and displaying POI markers

#### Test Steps

1. **Open POI Details Modal**
   - Navigate to the map view
   - Locate a POI marker on the map (star, place, or location icon)
   - Tap on any POI marker
   - **Expected Result**: Modal bottom sheet should slide up from the bottom with POI details

2. **Verify Modal Content**
   - **Expected Result**: Modal should display:
     - POI name in bold text
     - Interest level badge (Premium/Notable/Local)
     - Category chip (if not generic)
     - Description or loading indicator
     - Listen button (if description is available)
     - Drag handle at the top

3. **Test Tap-Outside Dismissal**
   - With the modal open, tap anywhere on the visible map area
   - **Expected Result**: Modal should dismiss and slide down out of view
   - **Alternative locations to test**:
     - Tap on the map background
     - Tap on another POI marker (should close current modal and open new one)
     - Tap on the semi-transparent overlay area

4. **Test Normal Modal Interactions Still Work**
   - Open the modal again
   - Test dragging the modal up and down using the drag handle
   - Test scrolling within the modal content
   - Test the Listen button functionality
   - **Expected Result**: All normal interactions should work as before

5. **Test Edge Cases**
   - **Multiple POI Taps**: Rapidly tap different POI markers
     - **Expected Result**: Only one modal should be open at a time
   - **Swipe to Dismiss**: Swipe down on the modal
     - **Expected Result**: Modal should still dismiss by swiping (original behavior)
   - **Tap on Modal Content**: Tap inside the modal content area
     - **Expected Result**: Modal should NOT dismiss

#### Cross-Platform Testing

Test the above scenarios on:
- iOS devices/simulator
- Android devices/emulator
- Different screen sizes (phones, tablets)
- Different orientations (portrait, landscape)

#### Regression Testing

Ensure the following existing functionality still works:
- POI markers display correctly with appropriate icons and sizes
- POI interest levels are correctly indicated by marker appearance
- POI descriptions load properly (with loading indicator)
- Text-to-speech functionality works
- Map interactions (zoom, pan, rotate) work normally
- Location services and centering work properly

#### Success Criteria

✅ POI modal opens when tapping POI markers
✅ POI modal dismisses when tapping outside the modal content
✅ POI modal dismisses when tapping the semi-transparent overlay
✅ Normal modal interactions (drag, scroll, buttons) continue to work
✅ No regressions in map or POI functionality
✅ Behavior is consistent across platforms and screen sizes

#### Known Limitations

- The fix specifically targets the `showModalBottomSheet` barrier dismissal
- Other modal types in the app may need similar fixes if they exist
- Very precise taps near the modal edge should be tested to ensure proper behavior