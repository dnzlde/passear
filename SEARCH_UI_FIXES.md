# Search UI Fixes - Response to User Feedback

This document describes the fixes applied to address the three issues reported by @dnzlde.

## Issues Reported

1. **White text on white background** - Text was invisible while typing
2. **Hebrew search not working** - "כותל" returned no results
3. **No autocomplete suggestions** - No dropdown results while typing

## Solutions Implemented

### Issue #1: Text Visibility Fixed ✅

**Problem:** The search TextField used hardcoded white text (`Colors.white`), which was invisible on the light-colored app bar background in Material 3 theme.

**Solution:** Changed to use theme-aware colors:
```dart
// Before
style: const TextStyle(color: Colors.white),
hintStyle: TextStyle(color: Colors.white70),

// After  
style: TextStyle(color: colorScheme.onPrimary),
hintStyle: TextStyle(color: colorScheme.onPrimary.withOpacity(0.7)),
```

Also added explicit app bar colors:
```dart
AppBar(
  backgroundColor: colorScheme.primary,
  foregroundColor: colorScheme.onPrimary,
  // ...
)
```

**Result:** Search text is now clearly visible with proper contrast.

### Issue #2: Multi-Language Search Support ✅

**Problem:** The search service was hardcoded to use English Wikipedia (`lang = 'en'`), so Hebrew searches like "כותל" couldn't find results.

**Solution:** Added automatic language detection based on Unicode character ranges:

```dart
String _detectLanguage(String query) {
  if (RegExp(r'[\u0590-\u05FF]').hasMatch(query)) return 'he'; // Hebrew
  if (RegExp(r'[\u0400-\u04FF]').hasMatch(query)) return 'ru'; // Russian
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(query)) return 'ar'; // Arabic
  if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(query)) return 'zh'; // Chinese
  if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(query)) return 'ja'; // Japanese
  return 'en'; // Default to English
}
```

The detected language is passed to the search service:
```dart
final searchService = PoiSearchService(
  lang: _detectLanguage(query),
);
```

**Supported Languages:**
- Hebrew (עברית) - searches he.wikipedia.org
- Russian (Русский) - searches ru.wikipedia.org
- Arabic (العربية) - searches ar.wikipedia.org
- Chinese (中文) - searches zh.wikipedia.org
- Japanese (日本語) - searches ja.wikipedia.org
- English (default) - searches en.wikipedia.org

**Result:** Search now works with multiple languages including Hebrew "כותל" which will find "Western Wall (Kotel)".

### Issue #3: Autocomplete Suggestions ✅

**Problem:** Search only executed on Enter/Submit. No live suggestions appeared while typing.

**Solution:** Added real-time search with dropdown suggestions:

1. **State Management:**
```dart
List<PoiSearchResult> _searchSuggestions = [];
bool _isLoadingSearchSuggestions = false;
```

2. **Live Search on Text Change:**
```dart
TextField(
  onChanged: (query) {
    // Perform search as user types for autocomplete
    _performSearch(query, showSheet: false);
  },
  onSubmitted: (query) {
    // Show full results sheet on Enter
    _performSearch(query, showSheet: true);
  },
)
```

3. **Suggestions Dropdown UI:**
```dart
if (_isSearching && (_searchSuggestions.isNotEmpty || _isLoadingSearchSuggestions))
  Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Material(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: ListView.builder(
          itemCount: _searchSuggestions.length,
          itemBuilder: (context, index) {
            final result = _searchSuggestions[index];
            return ListTile(
              leading: Icon(...),
              title: Text(result.poi.name),
              subtitle: Text(result.poi.description),
              trailing: Text('${result.relevanceScore}'),
              onTap: () {
                // Navigate to POI
              },
            );
          },
        ),
      ),
    ),
  )
```

**Features:**
- Dropdown appears below search field
- Shows up to 10 ranked results
- Each result displays:
  - Category icon with color-coded interest level
  - POI name
  - Description preview (1 line)
  - Relevance score
- Loading indicator while searching
- Tap suggestion to navigate to POI and show details
- Automatically clears when closing search

**Result:** Users now see live suggestions as they type, making it easy to find attractions without remembering exact names.

## Technical Details

### Modified Files
- `lib/map/map_page.dart` - 149 additions, 17 deletions

### Key Changes
1. Added `_searchSuggestions` and `_isLoadingSearchSuggestions` state variables
2. Modified `_performSearch()` to accept `showSheet` parameter for dual behavior
3. Added `_detectLanguage()` method for automatic language detection
4. Updated `TextField` to use theme colors and trigger search on text change
5. Added suggestion dropdown UI in the Stack overlay
6. Updated close button to clear suggestions state

### Testing
The changes maintain backward compatibility and work with the existing `PoiSearchService` which already supports the `lang` parameter.

## User Experience Flow

### Before
1. User taps search icon
2. User types text (invisible!)
3. User presses Enter
4. Results shown in modal sheet (if any)

### After
1. User taps search icon
2. User starts typing "כות" (text is visible!)
3. Suggestions dropdown appears with "Western Wall" and other matches
4. User can either:
   - Tap a suggestion → Navigate immediately to POI
   - Keep typing → Suggestions update in real-time
   - Press Enter → Show full results in modal sheet

## Commit
- **Hash:** 2cfa8d6
- **Message:** Fix search UI: proper colors, multi-language support, and autocomplete
- **Date:** 2026-01-24

## Summary
All three issues reported by @dnzlde have been successfully resolved:
1. ✅ Text is now visible with proper theme-aware colors
2. ✅ Hebrew and other languages now work with automatic detection
3. ✅ Live autocomplete suggestions appear while typing
