# Tell Me More Feature

## Overview
The "Tell Me More" feature enhances the AI Story functionality by providing extended, detailed narratives for important Points of Interest (POIs) that have significant additional content available.

## How It Works

### 1. Initial AI Story Generation
When a user requests an AI Story for a POI:
- The standard AI story is generated (3-5 paragraphs)
- The story is automatically played via text-to-speech
- The story appears in the UI with a "Play Again" button

### 2. Content Availability Check
After the initial story is generated, the system:
- Automatically checks if there's significantly more interesting content available
- Uses the LLM to analyze the POI's significance and available information
- Shows a small loading indicator during this check

### 3. Tell Me More Button
If substantial additional content is available:
- A "Tell Me More" button appears next to the "Play Again" button
- The button is styled in deep purple to distinguish it from the regular AI Story
- The button only appears for POIs that have rich, detailed information

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
- Historical significance and depth
- Architectural or artistic details
- Notable events or stories
- Cultural importance
- Unique or fascinating facts

## Technical Implementation

### New Methods in LlmService

#### `hasMoreContent()`
```dart
Future<bool> hasMoreContent({
  required String poiName,
  required String poiDescription,
})
```
- Checks if POI has substantial additional content
- Returns true/false based on LLM analysis
- Fails gracefully (returns false) to avoid interrupting user experience

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
4. System checks for additional content (in background)
5. If available, "Tell Me More" button appears
6. User can choose to hear the extended story
7. Extended story is generated and plays automatically

## Benefits

- **Non-intrusive**: Button only appears when relevant
- **User-controlled**: Users decide if they want more details
- **Quality content**: Stories are interesting and informative
- **Efficient**: Content check happens asynchronously
- **Cached**: Both regular and extended stories are cached

## Testing

Comprehensive tests have been added for:
- Content availability checking
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
