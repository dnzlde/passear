# User Location Marker - Visual Design

## Marker Appearance

The user location marker consists of multiple layers:

```
┌──────────────────────────────┐
│                              │
│    ╭─────────────────────╮   │  <- Outer Circle (60x60)
│   ╱                       ╲  │     Light Blue @ 20% opacity
│  │   ╭───────────────╮     │ │
│  │  ╱  Middle Circle  ╲    │ │  <- Middle Circle (40x40)
│  │ │   White Border    │   │ │     Blue @ 30% opacity
│  │ │                   │   │ │     2px white border
│  │ │   ╭─────────╮     │   │ │
│  │ │  ╱  Solid    ╲    │   │ │  <- Inner Dot (20x20)
│  │ │ │    Blue     │   │   │ │     Solid Blue
│  │ │  ╲  Center   ╱    │   │ │
│  │ │   ╰─────────╯     │   │ │
│  │ │      ▲            │   │ │  <- Direction Arrow
│  │ │      │            │   │ │     (when heading available)
│  │  ╲   (arrow)       ╱    │ │     White, 16px
│  │   ╰───────────────╯     │ │     Rotates based on heading
│   ╲                       ╱  │
│    ╰─────────────────────╯   │
│                              │
└──────────────────────────────┘
```

## Color Scheme

- **Outer Circle**: `Colors.blue.withOpacity(0.2)` - Light blue with 20% opacity
- **Middle Circle**: `Colors.blue.withOpacity(0.3)` - Blue with 30% opacity
- **Border**: `Colors.white` - 2px white border on middle circle
- **Inner Dot**: `Colors.blue` - Solid blue
- **Arrow**: `Colors.white` - White navigation icon

## Direction Indicator

When device heading is available (compass data):
- Arrow points in the direction the user is facing
- Rotates smoothly as user turns
- Arrow is `Icons.navigation` (triangle/arrow shape)
- Size: 16px

When heading is NOT available:
- Only shows the concentric circles
- No directional arrow

## Behavior

1. **Updates automatically** every 5 meters of movement
2. **Always on top** of POI markers (rendered last)
3. **Visible at all zoom levels** with fixed 60x60 size
4. **Follows GPS position** in real-time

## Distinguishing from POI Markers

| Feature | User Location | POI Markers |
|---------|--------------|-------------|
| Shape | Circular (3 layers) | Icon-based (star/pin/location) |
| Color | Blue shades | Amber/Blue/Grey |
| Size | Fixed 60x60 | 30-50 (varies by importance) |
| Movement | Updates in real-time | Static positions |
| Direction | Shows heading | No direction |
| Tap action | None | Opens POI details |

## Map Integration

The user location marker is added as a separate `MarkerLayer`:

```dart
// User location marker
if (_userLocation != null)
  MarkerLayer(
    markers: [
      Marker(
        width: 60,
        height: 60,
        point: _userLocation!,
        child: _buildUserLocationMarker(),
      ),
    ],
  ),
```

This ensures it:
- ✅ Renders on top of POI markers
- ✅ Only appears when location is available
- ✅ Updates position automatically via `setState`
- ✅ Disappears gracefully when location unavailable

## Expected Visual Result

When the app runs:
1. Map loads with POI markers (stars, pins, etc.)
2. Blue pulsing dot appears at user's current location
3. If device has compass: white arrow points in facing direction
4. As user moves: marker updates position smoothly
5. As user rotates: arrow rotates to show new heading

The design is similar to Google Maps' user location indicator but with a unique three-layer circular design for better visibility.
