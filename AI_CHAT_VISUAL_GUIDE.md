# AI Chat Feature - Visual Guide

## UI Layout and Flow

### 1. Entry Point - POI Detail Sheet

**Location**: Bottom sheet that appears when user taps a POI marker on the map

**New Button**: "Ask the Guide"
- Position: Full-width button above "Listen" and "Navigate" buttons
- Color: Indigo background with white text
- Icon: Chat bubble icon (Icons.chat)
- State: Enabled when user location is available and LLM is configured

**Visual Hierarchy**:
```
┌────────────────────────────────────┐
│  POI Name                     ★★★  │
│                                    │
│  Description text...               │
│                                    │
│  ┌──────────────────────────────┐ │
│  │   🗨  Ask the Guide          │ │ <- NEW BUTTON
│  └──────────────────────────────┘ │
│                                    │
│  ┌────────────┐  ┌──────────────┐ │
│  │ 🔊 Listen  │  │ 🚶 Navigate  │ │
│  └────────────┘  └──────────────┘ │
└────────────────────────────────────┘
```

### 2. Chat Page

**App Bar**:
- Title: "Ask the Guide"
- Left: Back arrow button
- Background: Light primary color

**Message Area** (Scrollable):
- Background: White/light gray
- Padding: 8px all around
- Auto-scrolls to bottom on new messages

**Message Bubbles**:

**Welcome Message** (appears on chat open):
```
┌────────────────────────────────────┐
│  🤖  Hello! I'm your AI guide.     │
│      Ask me anything about the     │
│      nearby places!                │
└────────────────────────────────────┘
```

**User Message** (right-aligned):
```
                    ┌──────────────┐
            What is │  👤          │
           nearby?  └──────────────┘
```

**Assistant Message** (left-aligned with TTS button):
```
┌─────────────────────────────────────┐
│  🤖  Based on nearby POIs, there    │
│      are several interesting        │
│      places...                      │
│                                     │
│      🔊                             │
└─────────────────────────────────────┘
```

**Error Message** (left-aligned with error icon):
```
┌─────────────────────────────────────┐
│  ⚠️  No points of interest found    │
│      nearby. Try moving to a        │
│      different location...          │
└─────────────────────────────────────┘
```

**Input Area** (bottom, fixed):
```
┌────────────────────────────────────┐
│  ┌────────────────────────┐  📤   │
│  │ Ask about nearby...    │       │
│  └────────────────────────┘       │
└────────────────────────────────────┘
```

### 3. Loading States

**Thinking State**:
```
┌────────────────────────────────────┐
│  ⏳  Thinking...                    │
└────────────────────────────────────┘
```

**Input Disabled** (during loading):
```
┌────────────────────────────────────┐
│  ┌────────────────────────┐  📤   │
│  │ Ask about nearby... (disabled)  │
│  └────────────────────────┘       │
└────────────────────────────────────┘
```

## Color Scheme

### Primary Colors
- **User Messages**: Theme primary color (indigo)
  - Background: Solid primary color
  - Text: White

- **Assistant Messages**: Light gray
  - Background: Colors.grey.shade200
  - Text: Colors.black87

- **Error Messages**: Red
  - Background: Colors.red.shade50
  - Text: Colors.red.shade900

### Accents
- **Icons**: 
  - User avatar: Theme secondary color
  - Assistant avatar: Theme primary color
  - Error icon: Red
  - TTS button: Default text color

- **Button States**:
  - Enabled: Full opacity
  - Disabled: Reduced opacity (automatic)
  - Pressed: Material ripple effect

## Interaction Flow

### Happy Path
1. User opens POI detail sheet
2. User taps "Ask the Guide" button
3. Chat page slides in from right
4. Welcome message is displayed
5. User types question in input field
6. User taps send button or presses Enter
7. User message appears on right
8. Loading indicator shows "Thinking..."
9. Assistant response appears on left
10. User can tap TTS button to hear response
11. User can ask follow-up questions
12. User taps back button to return to map

### Error Paths

**No Location Available**:
1. User taps "Ask the Guide" button
2. Snackbar appears: "Location not available. Please enable location services."
3. User remains on POI detail sheet

**LLM Not Configured**:
1. User taps "Ask the Guide" button
2. Dialog appears: "LLM Not Configured"
3. Message explains need for API key in settings
4. User taps "OK" to dismiss
5. User remains on POI detail sheet

**No POIs Nearby**:
1. User sends question
2. System searches for POIs (250m radius)
3. No POIs found
4. Error message bubble appears in chat
5. User can try different question or location

**API Error**:
1. User sends question
2. LLM API request fails
3. Error message bubble appears with details
4. User can retry question

## Typography

### Font Sizes
- **POI Name**: 20pt, Bold
- **Chat Message**: Default (16pt)
- **Input Placeholder**: Default (16pt)
- **Loading Text**: Default (16pt)
- **Button Labels**: Default (16pt)

### Font Weights
- **Bold**: POI name, section headers
- **Normal**: Message text, input text
- **Medium**: Button labels

## Spacing

### Margins
- **Screen padding**: 8px
- **Message vertical spacing**: 4px
- **Button horizontal spacing**: 8px
- **Input field padding**: 16px horizontal, 12px vertical

### Border Radius
- **Message bubbles**: 16px
- **Input field**: Standard Material border
- **Buttons**: Standard Material shape

## Animations

### Transitions
- **Page entrance**: Slide from right (Material default)
- **Message appearance**: Fade in with scale
- **Scroll to bottom**: Smooth animation (300ms)
- **Button press**: Material ripple

### Loading States
- **Circular progress**: Rotating animation (20px)
- **Text**: No animation, static

## Accessibility

### Screen Reader Labels
- **Chat button**: "Ask the guide about nearby places"
- **Send button**: "Send message"
- **TTS button**: "Play audio of this message"
- **Back button**: "Return to map"

### Touch Targets
- **Minimum size**: 48x48 dp (Material standard)
- **Button height**: 48 dp
- **Icon size**: 24 dp

### Contrast
- **Text on light**: Black/dark gray (WCAG AA compliant)
- **Text on dark**: White (WCAG AA compliant)
- **Error text**: Red.shade900 on Red.shade50 (high contrast)

## Platform Differences

### Android
- Uses Material Design 3 components
- System back button works to exit chat
- Keyboard "done" button sends message

### iOS
- Uses Cupertino-style components where appropriate
- Swipe from left edge to go back
- Keyboard "done" button sends message

## Testing Checklist

### Visual Testing
- [ ] Button appears in POI detail sheet
- [ ] Button is full-width and properly styled
- [ ] Chat page has correct app bar
- [ ] Welcome message displays on chat open
- [ ] User messages align right with avatar
- [ ] Assistant messages align left with icon
- [ ] Error messages show error icon
- [ ] TTS button appears on assistant messages
- [ ] Input field is properly positioned at bottom
- [ ] Send button is visible and accessible

### Interaction Testing
- [ ] Tapping button opens chat page
- [ ] Typing in input field works
- [ ] Send button sends message
- [ ] Enter key sends message
- [ ] Messages scroll to bottom
- [ ] TTS button plays audio
- [ ] TTS button stops audio when playing
- [ ] Back button returns to map
- [ ] Loading state shows during processing
- [ ] Input disabled during loading

### Error Testing
- [ ] No location shows snackbar
- [ ] No LLM config shows dialog
- [ ] No POIs shows error message
- [ ] API error shows error message
- [ ] Errors are readable and helpful

### Responsive Testing
- [ ] Works on small screens (320dp width)
- [ ] Works on large screens (tablet)
- [ ] Keyboard doesn't cover input field
- [ ] Message bubbles don't overflow
- [ ] Long messages wrap properly

## Example Screenshots Needed

For documentation/PR review:
1. POI detail sheet with "Ask the Guide" button
2. Chat page with welcome message
3. Chat with user question and assistant response
4. TTS button highlighted
5. Error message example
6. Loading state
7. Multiple messages in conversation
8. Keyboard visible with input field

## Edge Cases to Test

1. **Very long messages**: Should wrap correctly
2. **Rapid sending**: Multiple messages in quick succession
3. **Network interruption**: During API call
4. **Location changes**: While chat is open
5. **App backgrounding**: Chat state preserved
6. **Rotation**: Layout adapts (if rotation enabled)
7. **Special characters**: Emojis, unicode in messages
8. **Empty message**: Send button should be disabled
9. **Multiple POIs**: Context includes multiple sources
10. **No POI descriptions**: Handles missing data gracefully
