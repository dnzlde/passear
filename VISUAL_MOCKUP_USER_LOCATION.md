# Visual Mockup: User Location Marker on Map

## Before and After Comparison

### BEFORE (Original Implementation)
```
┌─────────────────────────────────────────────────┐
│ Passear                            ⚙️ Settings │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│           ⭐ POI 1                              │
│                                                 │
│                                                 │
│                  📍 POI 2                       │
│                                                 │
│                                                 │
│                            📌 POI 3            │
│                                                 │
│                                                 │
│  No visual indicator of user location!         │
│                                                 │
│                                         🧭 ⬆️   │
│                                         📍 📌   │
└─────────────────────────────────────────────────┘
         User's location is unknown to them
```

### AFTER (With User Location Marker)
```
┌─────────────────────────────────────────────────┐
│ Passear                            ⚙️ Settings │
├─────────────────────────────────────────────────┤
│                                                 │
│           ⭐ POI 1                              │
│                                                 │
│                  📍 POI 2                       │
│                                                 │
│              ◯◉⬆️  ← YOU ARE HERE!              │
│              User                               │
│             Location                            │
│             Marker                              │
│                                                 │
│                            📌 POI 3            │
│                                                 │
│                                                 │
│                                         🧭 ⬆️   │
│                                         📍 📌   │
└─────────────────────────────────────────────────┘
    User can clearly see their position and direction
```

## Detailed Marker Components

### Layer Breakdown
```
       Outer Circle (60×60)
       ┌─────────────────┐
       │  Light Blue 20% │
       │  ┌───────────┐  │
       │  │Middle 40×40│  │
       │  │Blue 30%    │  │
       │  │ ┌───────┐ │  │
       │  │ │Inner  │ │  │
       │  │ │20×20  │ │  │
       │  │ │ Solid │ │  │
       │  │ │ Blue  │ │  │
       │  │ │   ▲   │ │  │  ← Direction Arrow
       │  │ │   │   │ │  │     (rotates with heading)
       │  │ └───────┘ │  │
       │  │ White Brdr│  │
       │  └───────────┘  │
       └─────────────────┘
```

## User Scenarios

### Scenario 1: Walking in a City
```
┌─────────────────────────────────────────────────┐
│ Map View - Tel Aviv                           ⚙️│
├─────────────────────────────────────────────────┤
│                                                 │
│     Street A          Street B                  │
│    ═════════════════════════════                │
│         ║                                       │
│    Azrieli⭐               📍Museum              │
│         ║                                       │
│         ║      ◯◉⬆️  ← User walking north       │
│         ║       User                            │
│    ═════╬═════════════════════════              │
│    Street C                                     │
│         ║                                       │
│         📌Park                                  │
│                                                 │
│                                         🧭 ⬆️   │
│                                         📍 📌   │
└─────────────────────────────────────────────────┘
```

### Scenario 2: User Rotating/Turning
```
Position 1: Facing North    Position 2: Facing East
     ◯◉                          ◯◉
      ▲                           ▶
      │                           
  Heading: 0°                 Heading: 90°
```

### Scenario 3: Different Zoom Levels

**Zoom Level: Close (15-18)**
```
┌─────────────────────┐
│   Building          │
│      ⭐            │
│                     │
│       ◯◉⬆️          │
│      User           │
│     (visible)       │
│                     │
│   Street            │
└─────────────────────┘
```

**Zoom Level: Far (10-13)**
```
┌─────────────────────┐
│   City Overview     │
│  ⭐  ⭐  ⭐         │
│     ◯◉⬆️            │
│    User             │
│  (still visible)    │
│  📍  📌  ⭐         │
│                     │
└─────────────────────┘
```

## Color Palette

### User Location Marker
- **Outer Circle**: `rgba(33, 150, 243, 0.2)` - #2196F3 at 20% opacity
- **Middle Circle**: `rgba(33, 150, 243, 0.3)` - #2196F3 at 30% opacity
- **Border**: `rgb(255, 255, 255)` - White, 2px
- **Inner Dot**: `rgb(33, 150, 243)` - #2196F3 solid
- **Arrow**: `rgb(255, 255, 255)` - White

### POI Markers (for contrast)
- **High Interest**: `rgb(255, 193, 7)` - Amber ⭐
- **Medium Interest**: `rgb(33, 150, 243)` - Blue 📍
- **Low Interest**: `rgb(158, 158, 158)` - Gray 📌

## Movement Animation (Conceptual)

```
Time 0s:          Time 1s:          Time 2s:
User at A         User at B         User at C
◯◉⬆️              →  ◯◉⬆️            →  ◯◉⬆️
A     B     C        A     B     C       A     B     C

The marker smoothly follows GPS position updates
```

## Interaction States

### 1. Normal State (Location Available)
```
◯◉⬆️  ← Visible, tracking
```

### 2. No Compass Data
```
◯◉   ← No arrow, just circles
```

### 3. Location Permission Denied
```
(Marker not visible)
```

### 4. Poor GPS Signal
```
◯◉⬆️  ← Visible but may jump
```

## Comparison with POI Markers

```
User Location Marker:         POI Markers:
      ◯◉⬆️                    ⭐ High Interest
   (Concentric                📍 Medium Interest
    circles with              📌 Low Interest
    arrow)                    (Icon-based)

- Unique shape               - Various icons
- Blue theme                 - Color-coded
- Shows direction            - Static
- Real-time updates          - Fixed positions
- Cannot tap                 - Tap for details
```

## Expected User Experience

1. **App Launch**: 
   - Map loads
   - Blue marker appears at user's location
   - User sees "I'm here!"

2. **Walking Around**:
   - Marker follows user smoothly
   - POIs discovered as user moves
   - Direction arrow rotates with turns

3. **Interacting with POIs**:
   - User taps POI marker
   - Details sheet opens
   - User location still visible in background

4. **Returning to Location**:
   - User pans map away
   - Taps 📍 "Center to my location" button
   - Map animates back to user marker

## Technical Notes

- Marker size: Fixed 60×60 pixels at all zoom levels
- Update frequency: Every 5 meters of movement
- Rendering: Always on top of POI markers
- Performance: Minimal battery impact
- Compatibility: Works on iOS and Android

## Success Indicators

When testing, you should observe:
✅ Blue circular marker at your GPS location
✅ Arrow pointing in your facing direction (if compass available)
✅ Smooth position updates as you move
✅ Marker visible at all zoom levels
✅ Distinct from POI markers
✅ No lag or performance issues

---

**Note**: This is a conceptual mockup. The actual appearance will be rendered by Flutter on device/emulator and should match these specifications.
