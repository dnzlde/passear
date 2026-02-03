# AI Guide Chat Feature - "Ask the Guide"

## Overview

The "Ask the Guide" feature is an AI-powered chat interface that allows users to ask questions about nearby points of interest (POIs). The feature uses an LLM (Large Language Model) to provide context-aware answers based on information from nearby POIs within a 250-meter radius.

## Features

### Core Functionality

1. **Context-Aware Chat**
   - Automatically gathers POIs within 250 meters of user's location
   - Includes up to 5 nearest POIs with their descriptions in the context
   - Provides answers based exclusively on nearby POI information

2. **Interactive Chat Interface**
   - Full-screen chat page with message history
   - User and assistant message bubbles
   - Error handling with clear error messages
   - Welcome message to guide users

3. **Text-to-Speech Integration**
   - Each assistant response includes a TTS button
   - Uses the app's existing TTS service
   - Supports all configured TTS voices and settings

4. **Error Handling**
   - "No POIs nearby" error when user is in an empty area
   - API error handling with user-friendly messages
   - LLM configuration validation

## User Interface

### Access Point

The "Ask the Guide" button is available in the POI detail sheet:
- Opens when user taps on any POI marker
- Button is positioned above "Listen" and "Navigate" buttons
- Styled in indigo color with chat icon
- Full-width button for easy tapping

### Chat Page

- **App Bar**: Shows "Ask the Guide" title with back button
- **Message List**: Scrollable list of all messages
- **User Messages**: Appear on the right in primary color
- **Assistant Messages**: Appear on the left with support agent icon
- **Error Messages**: Appear on the left with error icon in red
- **Input Field**: Multi-line text field at the bottom
- **Send Button**: Icon button to submit questions
- **TTS Button**: Volume icon on assistant messages

## Technical Architecture

### New Components

1. **`lib/models/chat_message.dart`**
   - Data model for chat messages
   - Factory methods for user, assistant, and error messages
   - Unique ID generation using timestamp + counter

2. **`lib/services/guide_chat_service.dart`**
   - Coordinates POI gathering and LLM interaction
   - Manages 250-meter search radius
   - Limits context to 5 most relevant POIs
   - Handles error cases

3. **`lib/map/guide_chat_page.dart`**
   - Full chat UI implementation
   - Message history management
   - TTS integration
   - Loading states and error handling

4. **`lib/services/llm_service.dart` (Extended)**
   - New `chatWithGuide()` method
   - Formats POI context for LLM
   - Handles chat-specific prompts

### Modified Components

1. **`lib/map/wiki_poi_detail.dart`**
   - Added `userLocation` parameter
   - Added "Ask the Guide" button
   - Added `_openGuideChat()` method
   - Imports `guide_chat_page.dart` and `guide_chat_service.dart`

2. **`lib/map/map_page.dart`**
   - Passes `_userLocation` to `WikiPoiDetail`

## Configuration Requirements

### LLM Configuration

Users must configure an LLM API key in Settings to use the chat feature:
1. Open Settings from the map page
2. Navigate to LLM Settings
3. Enter OpenAI API key (or compatible endpoint)
4. Configure endpoint and model if needed

### Location Services

The feature requires location services to be enabled:
- Android: Location permission must be granted
- iOS: Location permission must be granted
- User location must be available on the map

## Usage Flow

1. User taps on a POI marker to open detail sheet
2. User taps "Ask the Guide" button
3. Chat page opens with welcome message
4. User types a question about nearby places
5. System gathers nearby POIs (250m radius)
6. System sends POI context + question to LLM
7. Assistant response appears in chat
8. User can optionally play response via TTS
9. User can ask follow-up questions

## Example Questions

- "What historical sites are nearby?"
- "Tell me about the architecture in this area"
- "What museums can I visit around here?"
- "What's the significance of this neighborhood?"
- "Are there any religious sites nearby?"

## Error Handling

### No POIs Nearby
- **Trigger**: User location is in an area with no POIs within 250m
- **Message**: "No points of interest found nearby. Try moving to a different location or zooming out on the map."
- **Displayed as**: Error message bubble in chat

### LLM Not Configured
- **Trigger**: User hasn't set up LLM API key in settings
- **Message**: Dialog explaining configuration requirement
- **Action**: User directed to configure settings

### Location Not Available
- **Trigger**: GPS/location services are disabled
- **Message**: "Location not available. Please enable location services."
- **Displayed as**: Snackbar message

### API Errors
- **Trigger**: LLM API request fails
- **Message**: "Failed to get response from guide: [error details]"
- **Displayed as**: Error message bubble in chat

## Testing

### Unit Tests

- **`test/models/chat_message_test.dart`**: Tests message model
- **`test/services/guide_chat_service_test.dart`**: Tests service logic
- **`test/services/llm_service_test.dart`**: Tests chat method

### Test Coverage

- ✅ Message creation (user, assistant, error)
- ✅ Unique ID generation
- ✅ POI gathering
- ✅ Error handling (no POIs, API errors)
- ✅ LLM configuration validation
- ✅ Empty context handling

### Manual Testing Checklist

- [ ] Open POI detail and tap "Ask the Guide"
- [ ] Ask question about nearby places
- [ ] Verify response is relevant to nearby POIs
- [ ] Test TTS playback of responses
- [ ] Test error handling (disable location)
- [ ] Test with no LLM configuration
- [ ] Test in area with no POIs
- [ ] Test multiple questions in conversation
- [ ] Verify UI is responsive and smooth

## Performance Considerations

### Network Usage

- POI data: Fetched from Wikipedia API (cached)
- LLM requests: ~400 tokens max per response
- Minimal bandwidth for text-based chat

### Response Times

- POI gathering: < 1 second (from cache)
- LLM response: 1-5 seconds (depends on API)
- TTS synthesis: Varies by engine (offline faster)

### Memory Usage

- Chat history stored in memory only
- No persistent storage (privacy-friendly)
- Messages cleared when chat page is closed

## Future Enhancements

Potential improvements for future versions:

1. **Conversation History**
   - Persist chat history per session
   - Allow viewing past conversations
   - Export conversations

2. **Contextual Follow-ups**
   - Include previous messages in context
   - Support multi-turn conversations
   - Remember user preferences

3. **Rich Media**
   - Show POI images in responses
   - Link to POIs on map from chat
   - Share response text

4. **Multilingual Support**
   - Detect user language
   - Respond in user's language
   - Translate POI descriptions

5. **Offline Mode**
   - Cache common questions/answers
   - Provide basic responses without LLM
   - Queue requests for later

## Accessibility

The feature is designed with accessibility in mind:

- **Screen Readers**: All UI elements have semantic labels
- **TTS Support**: Responses can be played aloud
- **Large Touch Targets**: Buttons are easy to tap
- **High Contrast**: Messages have clear visual distinction
- **Keyboard Navigation**: Text field supports standard input methods

## Privacy

- No conversation data is stored permanently
- POI data comes from public Wikipedia
- LLM API calls use user's own API key
- Location data only used for nearby POI search
- No tracking or analytics on chat content

## Troubleshooting

### Chat button not appearing
- Ensure POI detail sheet is fully opened
- Verify user location is available
- Check that POI has description loaded

### "No POIs nearby" error
- Move to a different location
- Try zooming out on map to see POI markers
- Check if POI provider is enabled in settings

### LLM not responding
- Verify API key is configured correctly
- Check internet connection
- Ensure API endpoint is reachable
- Check API rate limits

### TTS not working
- Verify TTS is enabled in settings
- Check device audio settings
- Ensure TTS engine is properly configured

## Code References

### Key Files
- Models: `lib/models/chat_message.dart`
- Services: `lib/services/guide_chat_service.dart`, `lib/services/llm_service.dart`
- UI: `lib/map/guide_chat_page.dart`, `lib/map/wiki_poi_detail.dart`
- Tests: `test/models/chat_message_test.dart`, `test/services/guide_chat_service_test.dart`

### Constants
- Search radius: `250 meters` (GuideChatService.searchRadiusMeters)
- Max POIs in context: `5` (GuideChatService.maxPoisInContext)
- Max response tokens: `400` (LlmService.chatWithGuide)
