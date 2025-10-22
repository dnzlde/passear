# Routing and Navigation Guide

This guide explains how to use the routing and navigation features in Passear for pedestrian navigation.

## Features

### Route Planning
- **Navigate to POIs**: Tap on any Point of Interest marker, then tap the "Navigate" button in the detail sheet
- **Navigate to Custom Points**: Long-press anywhere on the map to set a custom destination and start navigation
- **Pedestrian-Optimized Routes**: Routes are calculated specifically for walking, using pedestrian paths and walkways

### Navigation Display

#### Route Visualization
- **Blue Route Line**: The calculated walking route is displayed as a blue polyline on the map
- **Destination Marker**: A red pin marks your destination
- **Your Location**: Your current location is shown with a blue marker (with directional cone if heading is available)

#### Route Summary
Once a route is calculated, a summary card appears at the top of the screen showing:
- **Distance**: Total walking distance in meters or kilometers
- **Estimated Time**: Approximate walking time (based on 5 km/h walking speed)
- **Stop Button**: Close icon to cancel navigation

### Turn-by-Turn Navigation

#### Visual Instructions
When navigating, a navigation card appears at the bottom of the screen showing:
- **Current Instruction**: The next navigation action (e.g., "Turn left", "Continue straight")
- **Distance to Action**: How far until you need to perform the action
- **Progress Bar**: Visual indicator of navigation progress
- **Direction Icon**: Icon representing the type of turn or action

#### Voice Guidance
The app provides automatic voice announcements:
- **Route Summary**: Announced when navigation starts
- **Approaching Instructions**: Announced when you're within 50 meters of a turn
- **Immediate Actions**: Announced when you're within 20 meters
- **Arrival**: Announced when you reach your destination

### Navigation Controls

#### Starting Navigation
1. **From POI**: Tap a POI marker → Tap "Navigate" button
2. **Custom Location**: Long-press on map → Confirm in dialog → Navigation starts

#### During Navigation
- The map automatically fits to show your entire route
- Your current instruction updates as you move
- Voice guidance announces upcoming turns automatically

#### Stopping Navigation
- Tap the close (X) button on the route summary card
- Navigation clears the route and returns to normal map view

## Technical Details

### Routing Service
- **Primary**: OpenRouteService API for pedestrian routing
- **Fallback**: Straight-line routes when API is unavailable
- **Offline Support**: Simple fallback routes work without internet connection

### Route Calculation
- Routes are calculated between your current location and the destination
- Walking speed assumption: 5 km/h (1.39 m/s)
- Instruction proximity threshold: 50 meters for announcement
- Progress update frequency: Every 5 meters (based on location updates)

### Navigation Instructions
The app recognizes the following instruction types:
- Turn left / Turn right
- Turn sharp left / Turn sharp right
- Turn slight left / Turn slight right
- Continue straight
- Enter roundabout
- Arrive at destination

## Usage Tips

1. **Enable Location Services**: Ensure GPS/location services are enabled for accurate navigation
2. **Allow Microphone (if needed)**: Voice guidance requires TTS permissions
3. **Stay on Route**: The app shows your progress but doesn't automatically recalculate if you deviate
4. **Battery Usage**: Navigation mode uses GPS continuously, which may impact battery life
5. **Outdoor Use**: GPS accuracy is best outdoors with clear sky view

## API Configuration (For Developers)

### OpenRouteService Setup
The app uses OpenRouteService for routing. For production use:

1. Get a free API key from [OpenRouteService](https://openrouteservice.org/dev/#/signup)
2. Add the API key to your routing service implementation
3. Update the API endpoint configuration in `lib/services/routing_service.dart`

### Fallback Routing
The app includes a fallback routing mode that:
- Calculates straight-line distance
- Creates interpolated waypoints for smooth visualization
- Provides basic "head towards destination" instructions
- Works offline without API dependencies

## Known Limitations

1. **No Auto-Rerouting**: If you deviate from the route, you'll need to restart navigation
2. **Simple Fallback**: Offline mode provides only basic straight-line routing
3. **Voice Settings**: Voice guidance uses system TTS settings and language
4. **Route Persistence**: Routes are cleared when the app is closed
5. **API Limitations**: OpenRouteService has rate limits on free tier

## Future Enhancements

Planned improvements for routing and navigation:
- [ ] Auto-rerouting when user deviates from path
- [ ] Alternative route suggestions
- [ ] Saved routes and favorites
- [ ] Route sharing
- [ ] Elevation profiles
- [ ] Estimated calories burned
- [ ] Integration with fitness tracking apps

## Troubleshooting

### Route Not Calculating
- Check internet connection (for API routing)
- Verify location services are enabled
- Ensure you're not requesting routes to inaccessible locations

### Voice Not Working
- Check device volume settings
- Verify TTS (Text-to-Speech) is enabled in system settings
- Check app audio permissions

### Inaccurate Location
- Move outdoors for better GPS signal
- Enable high-accuracy location mode
- Wait a few seconds for GPS to stabilize

### Route Appears Incorrect
- Try restarting navigation
- Check if using fallback mode (API unavailable)
- Report persistent issues with location details

## Support

For issues or questions about routing and navigation:
- Open an issue on [GitHub](https://github.com/dnzlde/passear/issues)
- Include device model, OS version, and steps to reproduce
- Provide GPS coordinates if location-specific issue
