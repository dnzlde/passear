# POI Search Feature Implementation

This document describes the implementation of the POI (Point of Interest) search feature for the Passear Flutter application.

## Overview

The search feature allows users to search for tourist attractions by name, with intelligent context-aware ranking that considers:
- Text match quality (fuzzy search, multi-language support)
- User's current location
- Current visible map area
- Inherent importance of the POI

## User Story

**Scenario**: A tourist is told "If you're in Jerusalem, make sure to visit the Wailing Wall", but they don't know what it is or where it is.

**Solution**: The user can now:
1. Tap the search icon in the app bar
2. Type "Wailing Wall" (or similar terms in different languages)
3. See ranked search results with relevance scores
4. Tap a result to navigate to that location on the map

## Implementation

### 1. Search Service (`lib/services/poi_search_service.dart`)

The `PoiSearchService` class provides context-aware POI search:

```dart
Future<List<PoiSearchResult>> searchPois({
  required String query,
  LatLng? userLocation,
  MapBounds? mapBounds,
  int limit = 10,
})
```

**Key Features**:
- Uses Wikipedia's OpenSearch API for fuzzy, multi-language search
- Fetches geographic coordinates for each result
- Calculates relevance scores based on multiple factors:
  - **Text match quality** (0-40 points): How well the title matches the query
  - **Inherent POI interest** (0-30 points): Based on POI category and keywords
  - **Distance from user** (0-20 points): Closer POIs score higher
  - **Visibility in map bounds** (0-10 points): POIs in the visible area score higher
- Returns results sorted by relevance score (highest first)

### 2. UI Integration (`lib/map/map_page.dart`)

**Search UI**:
- Search icon in the app bar
- Tapping opens an inline search field
- Enter key submits the search
- Close icon exits search mode

**Search Results Display**:
- Modal bottom sheet with draggable scrollable list
- Each result shows:
  - POI name
  - Description (first 2 lines)
  - Category icon with color-coded interest level
  - Relevance score
- Tapping a result:
  - Closes the search sheet
  - Moves the map to the POI location
  - Shows the POI details in the bottom sheet

### 3. API Client Updates (`lib/services/api_client.dart`)

Extended `MockApiClient` to support:
- Wikipedia OpenSearch API (`action=opensearch`)
- Wikipedia Coordinates API (`prop=coordinates`)

This enables comprehensive testing without network calls.

### 4. Tests (`test/services/poi_search_service_test.dart`)

Comprehensive test suite covering:
- Empty query handling
- Search with coordinates retrieval
- Filtering results without coordinates
- Context-aware scoring (user location, map bounds)
- Limit parameter enforcement
- Error handling (graceful fallback)
- Missing descriptions handling
- Text match scoring
- POI categorization

**Test Results**: All 12 tests pass ✅

## Usage

### Searching for POIs

```dart
// Create search service
final searchService = PoiSearchService();

// Perform search with context
final results = await searchService.searchPois(
  query: 'Wailing Wall',
  userLocation: LatLng(31.7767, 35.2345), // User in Jerusalem
  mapBounds: MapBounds(
    north: 31.78,
    south: 31.77,
    east: 35.24,
    west: 35.23,
  ),
  limit: 10,
);

// Results are sorted by relevance
for (var result in results) {
  print('${result.poi.name}: ${result.relevanceScore}');
}
```

### User Experience

1. **Open Search**: Tap the search icon (🔍) in the app bar
2. **Enter Query**: Type attraction name (supports multiple languages)
3. **View Results**: See ranked list of matching attractions
4. **Navigate**: Tap a result to go to that location

## Multi-Language Support

The search is powered by Wikipedia's API, which:
- Performs fuzzy matching across languages
- Returns results from the Wikipedia language edition (default: English)
- Can be configured to search in other languages by setting the `lang` parameter

## Performance

- **Efficient API calls**: Uses Wikipedia's OpenSearch API (optimized for suggestions)
- **Batch coordinate fetching**: Retrieves coordinates for all results
- **Client-side scoring**: Relevance calculation happens locally
- **Result limit**: Configurable limit prevents excessive data transfer

## Future Enhancements

Possible improvements:
1. **Search history**: Cache recent searches for quick access
2. **Auto-suggestions**: Show suggestions as user types
3. **Language selection**: Allow users to choose search language
4. **Category filters**: Filter results by POI category
5. **Voice search**: Use speech-to-text for hands-free searching

## Testing

Run tests:
```bash
flutter test test/services/poi_search_service_test.dart
```

Run all tests:
```bash
flutter test
```

Format code:
```bash
dart format .
```

Verify formatting:
```bash
dart format --set-exit-if-changed .
```

## Technical Details

**Dependencies**:
- `latlong2`: Geographic coordinate handling
- `http`: HTTP requests to Wikipedia API
- Existing POI infrastructure (models, interest scoring)

**API Endpoints**:
- OpenSearch: `https://en.wikipedia.org/w/api.php?action=opensearch`
- Coordinates: `https://en.wikipedia.org/w/api.php?action=query&prop=coordinates`

**Scoring Algorithm**:
```
relevanceScore = textMatchScore * 40
               + (interestScore / 100) * 30
               + distanceScore * 20
               + visibilityScore * 10

Total: 0-100+ points
```

## Code Quality

- ✅ All tests pass (156 tests total, including 12 new search tests)
- ✅ Code formatted according to Dart style guide
- ✅ No new analyzer warnings
- ✅ Comprehensive documentation
- ✅ Error handling with graceful fallbacks
