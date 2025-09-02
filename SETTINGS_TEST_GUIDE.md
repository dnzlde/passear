# POI Settings Implementation - Manual Test Guide

## Overview
Added a comprehensive settings system for POI (Points of Interest) management with the following features:

### New Features:
1. **Settings Page**: Accessible via settings icon in the map app bar
2. **Category Management**: Toggle individual POI categories on/off
3. **POI Count Control**: Slider to adjust maximum POIs displayed (5-50)
4. **Quick Actions**: Enable/Disable all categories at once
5. **Persistent Storage**: Settings saved using SharedPreferences

### POI Categories Available:
- Museums (🏛️)
- Historical Sites (🏰)
- Landmarks (🗻)
- Religious Sites (🕌)
- Parks (🌳)
- Monuments (🗿)
- Universities (🎓)
- Theaters (🎭)
- Galleries (🎨)
- Architecture (🏗️)
- Generic/Other POIs (📍)

## Manual Testing Instructions:

### Test 1: Access Settings
1. Open the map page
2. Look for the settings icon (⚙️) in the app bar (top right)
3. Tap the settings icon
4. Verify the settings page opens

### Test 2: Category Toggle Testing
1. In settings, verify all 11 POI categories are listed
2. Toggle various categories off/on
3. Verify each category has:
   - Descriptive name (e.g., "Museums")
   - Technical name (e.g., "museum")
   - Appropriate icon
   - Working toggle switch

### Test 3: POI Count Control
1. Locate the "Maximum POIs to Display" slider
2. Verify it shows current value (default: 20)
3. Adjust slider from 5 to 50
4. Verify the current value updates

### Test 4: Quick Actions
1. Tap "Enable All" button
2. Verify all category toggles turn on
3. Tap "Disable All" button
4. Verify all category toggles turn off

### Test 5: Settings Persistence
1. Change several settings
2. Return to map (back button)
3. Verify POIs update based on settings
4. Re-enter settings
5. Verify settings are saved correctly

### Test 6: POI Filtering
1. Disable some POI categories in settings
2. Return to map
3. Verify only POIs from enabled categories appear
4. Check that disabled categories don't show on map

## Expected UI Layout:

### Settings Page Structure:
```
POI Settings
├── Summary Card
│   ├── "POI Display Settings"
│   ├── "Categories enabled: X of 11"
│   └── "Max POIs to show: XX"
├── POI Count Card
│   ├── "Maximum POIs to Display"
│   ├── Slider (5-50)
│   └── Current value display
├── Categories Card
│   ├── "POI Categories" 
│   ├── Description text
│   └── List of 11 category toggles
└── Quick Actions Card
    ├── "Enable All" button
    └── "Disable All" button
```

### Map Page Changes:
- Settings icon (⚙️) added to app bar
- POIs filtered based on enabled categories
- POI count respects settings

## Code Architecture:

### New Files:
- `lib/models/settings.dart` - Settings data model
- `lib/services/settings_service.dart` - Settings persistence
- `lib/settings/settings_page.dart` - Settings UI

### Modified Files:
- `lib/services/poi_service.dart` - Added category filtering
- `lib/map/map_page.dart` - Added settings navigation
- `pubspec.yaml` - Added shared_preferences dependency

## Testing Notes:
- Settings should persist between app restarts
- POI filtering should be immediate when returning from settings
- UI should be responsive and intuitive
- All category icons should be appropriate and recognizable