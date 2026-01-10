# Tell Me More Feature

## Overview
The "Tell Me More" feature enhances the AI Story functionality by providing extended, detailed narratives for **important** Points of Interest (POIs) that have significant additional content available.

## Important: POI Filtering
**The button only appears for POIs marked as important:**
- POIs with `PoiInterestLevel.high` (premium/star markers)
- POIs with `PoiInterestLevel.medium` (standard notable markers)
- POIs with `PoiInterestLevel.low` are **excluded** to focus on truly significant landmarks

This filtering ensures the feature focuses on major landmarks and historically significant sites where extended content provides real value.

## How It Works

### 1. Initial AI Story Generation
When a user requests an AI Story for a POI:
- The standard AI story is generated (3-5 paragraphs)
- The story is automatically played via text-to-speech
- The story appears in the UI with a "Play Again" button

### 2. Content Availability Check (For Important POIs Only)
After the initial story is generated, **if the POI has high or medium interest level**:
- The system automatically checks if there's more interesting content available
- Uses the LLM to analyze the POI's significance and available information
- Shows a small loading indicator during this check
- Debug logging tracks the check process for troubleshooting

### 3. Tell Me More Button
If additional content is available:
- A "Tell Me More" button appears next to the "Play Again" button
- The button is styled in deep purple to distinguish it from the regular AI Story
- The button only appears for POIs that pass both the interest level filter AND the content check

### 4. Extended Story Generation
When the user clicks "Tell Me More":
- An extended story is generated with more details
- Length is adaptive: 5-8 paragraphs (400-700 words) for major landmarks, 3-4 paragraphs (250-400 words) for moderate sites
- The extended story automatically plays via text-to-speech
- Displayed in a separate container with "Extended Story" header

## Key Features

### Quality Over Quantity
- Stories avoid generic introductions ("Welcome to...")
- Minimizes formulaic conclusions
- Focuses on interesting, valuable content
- Each sentence provides real value

### Adaptive Length
The system automatically adjusts story length based on:
- POI significance and historical importance
- Amount of interesting information available
- Content quality (no filler or padding)

### Smart Content Detection
The LLM evaluates whether there's more content by considering:
- Historical background, events, or significance
- Architectural features or artistic elements
- Cultural or religious importance
- Interesting stories, legends, or facts
- Notable people or events associated with the place

## Technical Implementation

### POI Interest Level Filter
Before checking for additional content, the system filters POIs by interest level:
```dart
if (currentPoi.interestLevel == PoiInterestLevel.low) {
  return; // Skip content check for low-interest POIs
}
```

This ensures the feature focuses on:
- **High interest POIs**: Major landmarks (star-shaped, golden markers)
- **Medium interest POIs**: Notable sites (standard blue markers)

### New Methods in LlmService

#### `hasMoreContent()`
```dart
Future<bool> hasMoreContent({
  required String poiName,
  required String poiDescription,
})
```
- Checks if POI has additional interesting content
- Returns true if 1-2+ additional aspects can be explored
- Returns false on any error (config invalid, API error, etc.)
- Includes debug logging for troubleshooting
- Gracefully handles errors to avoid interrupting user experience

#### `generateExtendedStory()`
```dart
Future<String> generateExtendedStory({
  required String poiName,
  required String poiDescription,
  required String originalStory,
  StoryStyle style = StoryStyle.neutral,
})
```
- Generates detailed extended story
- Uses original story context to avoid repetition
- Supports same style options as regular stories
- Uses more tokens (max 1200) for detailed content

### UI State Management

New state variables in `WikiPoiDetail`:
- `hasMoreContent`: Whether the button should be shown
- `isCheckingMoreContent`: Loading state during content check
- `extendedStory`: The generated extended story text
- `isGeneratingExtendedStory`: Loading state during extended story generation

## User Experience Flow

1. User taps on a POI marker
2. User taps "AI Story" button
3. Story is generated and plays automatically
4. **If POI has high or medium interest level:**
   - System checks for additional content (in background)
   - Debug logs track the check process
   - If available, "Tell Me More" button appears
5. User can choose to hear the extended story
6. Extended story is generated and plays automatically

## Benefits

- **Focused on important POIs**: Only checks high/medium interest level landmarks
- **Non-intrusive**: Button only appears when relevant
- **User-controlled**: Users decide if they want more details
- **Quality content**: Stories are interesting and informative
- **Efficient**: Content check happens asynchronously only for important POIs
- **Cached**: Both regular and extended stories are cached
- **Debuggable**: Comprehensive logging for troubleshooting

## Troubleshooting

### Button Not Appearing?

1. **Check POI Interest Level**: The button only appears for high or medium interest POIs
   - Look for debug logs: `_checkForMoreContent: Skipping check - POI has low interest level`
   
2. **Check LLM Configuration**: Ensure your API key is configured
   - Look for: `hasMoreContent: LLM not configured, returning false`
   
3. **Check LLM Response**: The LLM might be returning "NO"
   - Look for: `hasMoreContent: LLM response: "NO"`
   
4. **Enable Debug Logging**: Run in debug mode to see detailed logs

Example debug output for a successful check:
```
_checkForMoreContent: Starting check for POI: Western Wall (interest level: PoiInterestLevel.high)
hasMoreContent: Checking content for POI: Western Wall
hasMoreContent: LLM response: "YES"
hasMoreContent: Returning true for Western Wall
_checkForMoreContent: Result for Western Wall: true
```

## Testing

Comprehensive tests have been added for:
- Content availability checking (YES/NO responses)
- Invalid configuration handling
- Extended story generation
- Caching behavior
- Error handling
- API integration

## Future Enhancements

Potential improvements:
- Pre-generate extended stories for popular POIs
- Support for multiple "Tell Me More" levels
- Visual indicators for POI significance
- User feedback on story quality
