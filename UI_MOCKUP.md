# POI Settings UI Mock Screenshots

## Settings Page Layout Description

### Header
```
┌─────────────────────────────┐
│ ← POI Settings             │ (App Bar)
└─────────────────────────────┘
```

### Summary Card
```
┌─────────────────────────────┐
│ POI Display Settings        │
│                             │
│ Categories enabled: 11 of 11│
│ Max POIs to show: 20        │
└─────────────────────────────┘
```

### POI Count Control Card
```
┌─────────────────────────────┐
│ Maximum POIs to Display     │
│                             │
│ ●────────○─────── (Slider)  │
│ 5               50          │
│ Current: 20 POIs            │
└─────────────────────────────┘
```

### POI Categories Card
```
┌─────────────────────────────┐
│ POI Categories              │
│ Toggle which types of POIs  │
│ to show on the map          │
│                             │
│ 🏛️ Museums        [ON] ●○   │
│    museum                   │
│ 🏰 Historical Sites [ON] ●○ │
│    historicalSite           │
│ 🗻 Landmarks      [ON] ●○   │
│    landmark                 │
│ 🕌 Religious Sites [ON] ●○  │
│    religiousSite            │
│ 🌳 Parks          [ON] ●○   │
│    park                     │
│ 🗿 Monuments      [ON] ●○   │
│    monument                 │
│ 🎓 Universities   [ON] ●○   │
│    university               │
│ 🎭 Theaters       [ON] ●○   │
│    theater                  │
│ 🎨 Galleries      [ON] ●○   │
│    gallery                  │
│ 🏗️ Architecture   [ON] ●○   │
│    architecture             │
│ 📍 Other POIs     [ON] ●○   │
│    generic                  │
└─────────────────────────────┘
```

### Quick Actions Card
```
┌─────────────────────────────┐
│ Quick Actions               │
│                             │
│ [✓ Enable All] [✗ Disable All]
└─────────────────────────────┘
```

## Map Page Changes

### App Bar with Settings
```
┌─────────────────────────────┐
│ Passear              ⚙️     │
└─────────────────────────────┘
```

## Color Scheme & Visual Design
- Cards with Material Design elevation
- Toggle switches in app's primary color (indigo)
- Slider in primary color
- Icons in appropriate colors (matching categories)
- Clean, modern Material 3 design
- Responsive layout for different screen sizes

## Interaction Flow
1. User taps ⚙️ icon → Settings page opens
2. User adjusts settings → Changes saved automatically
3. User taps back arrow → Returns to map
4. Map automatically reloads POIs based on new settings

This creates a comprehensive settings interface that's intuitive and follows Material Design principles.