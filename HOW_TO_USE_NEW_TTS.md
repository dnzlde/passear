# How to Use the New Multilingual TTS

The new TTS system has been successfully integrated into the app! Here's what you need to know:

## What Changed

The app now uses **TtsOrchestrator** instead of the old **LocalTtsService**. This new system provides:

1. **OpenAI TTS** (cloud-based, high quality) as the primary engine
2. **Automatic fallback** to flutter_tts when offline or without API key
3. **Multilingual support** with automatic language detection
4. **Code-switching** - mixed language text is handled properly

## How to Enable OpenAI TTS

To use the high-quality OpenAI TTS, you need to:

### 1. Get an OpenAI API Key
- Go to https://platform.openai.com/api-keys
- Create a new API key
- Copy the key (starts with `sk-...`)

### 2. Add the API Key to App Settings
- Open the Passear app
- Go to **Settings** (gear icon)
- Scroll down to find the **TTS Settings** section
- Enter your OpenAI API key in the **OpenAI TTS API Key** field
- (Optional) Choose a voice from: alloy, echo, fable, onyx, nova, shimmer
- Save the settings

### 3. Test It!
- View any POI (Point of Interest)
- Tap the play button to hear the description
- The app will now use OpenAI TTS for high-quality, natural speech

## What Happens Without an API Key?

If you don't provide an OpenAI API key, the app will automatically fall back to the old flutter_tts system. You'll still get audio, but:
- Quality will be lower
- Multilingual text may not work as well
- Mixed language support will be limited

## Examples of Improved Behavior

### Before (Old TTS)
- Text: "Hello שלום world" → Hebrew part might be skipped or mispronounced

### After (New TTS with OpenAI)
- Text: "Hello שלום world" → Properly pronounces all parts in their respective languages

## System Language Detection

The new TTS automatically detects your device's system language and uses it as the default for Latin text. For example:
- If your device is set to Spanish, Latin text will be spoken with Spanish pronunciation
- Hebrew, Arabic, Cyrillic, CJK characters are automatically detected and spoken in their native languages

## Voice Guidance for Navigation

The navigation voice guidance also uses the new TTS system, providing clearer turn-by-turn directions.

## Troubleshooting

**Q: I entered my API key but still hear the old voice**
- Make sure you saved the settings
- Restart the audio playback
- Check that your API key is valid (starts with `sk-`)

**Q: I get an error when playing audio**
- Check your internet connection (OpenAI TTS requires internet)
- Verify your API key has sufficient credits
- The app will automatically fall back to offline TTS if there's a problem

**Q: How do I know which TTS is being used?**
- OpenAI TTS: High quality, natural sounding, MP3 format
- Fallback TTS: Standard quality, more robotic, local synthesis

## Privacy & Tech Debt Note

⚠️ **Important**: Currently, the API key is stored locally in your app. This is a temporary solution. In a future update, TTS requests will go through a backend server for better security.
