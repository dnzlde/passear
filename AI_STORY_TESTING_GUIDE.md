# AI Story Testing Guide

## Overview
The AI Story feature allows you to generate engaging, AI-powered narratives about Points of Interest (POI) using a Large Language Model (LLM). This guide will help you configure and test this feature.

## Prerequisites

### 1. Get an OpenAI API Key
To use the AI story feature, you need an API key from OpenAI:

1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Sign up or log in to your account
3. Navigate to **API Keys** section
4. Click **"Create new secret key"**
5. Copy your API key (it starts with `sk-...`)
6. **Important**: Keep this key secure and never share it publicly

### 2. Alternative: Use Compatible LLM Services
You can also use OpenAI-compatible services:
- **Local LLMs**: LM Studio, Ollama, LocalAI
- **Cloud Services**: Azure OpenAI, Anthropic Claude (with proxy), etc.

## Configuration Steps

### Step 1: Open App Settings
1. Launch the Passear app
2. Tap the **Settings** icon (⚙️) in the app
3. Scroll down to find the **"AI Story Configuration"** section

### Step 2: Configure LLM Settings
You'll see three fields to configure:

#### API Key (Required)
- Paste your OpenAI API key here
- The field is masked for security
- Example: `sk-proj-...` (your actual key)

#### API Endpoint (Optional)
- Default: `https://api.openai.com/v1/chat/completions`
- Change only if using a different service
- Examples:
  - Azure OpenAI: `https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2024-02-15-preview`
  - Local LM Studio: `http://localhost:1234/v1/chat/completions`
  - Local Ollama: `http://localhost:11434/v1/chat/completions`

#### Model (Optional)
- Default: `gpt-3.5-turbo`
- Other options:
  - `gpt-4` (more accurate but more expensive)
  - `gpt-4-turbo` (faster GPT-4)
  - `gpt-3.5-turbo-16k` (longer context)
  - For local models: use the model name from your LLM service

### Step 3: Verify Configuration
After entering your API key, you should see:
- **Green badge**: "LLM Configured" ✓
- This means the AI Story feature is ready to use

If you see:
- **Orange badge**: "LLM Not Configured" ⚠️
- This means you need to enter an API key

## Using the AI Story Feature

### Step 1: Find a POI
1. Navigate the map to see nearby Points of Interest
2. Tap on any POI marker to open its detail card

### Step 2: Generate AI Story
1. In the POI detail card, you'll see a purple button: **"AI Story"**
2. Tap the **"AI Story"** button
3. Wait while the story is being generated (loading indicator appears)
4. The AI-generated story will appear in a styled container
5. The story will automatically start playing through text-to-speech (TTS)

### Step 3: Listen and Enjoy
- The story is automatically read aloud using the device's TTS
- You can read along in the displayed text
- Use the **"Play Again"** button to hear the story again

## Story Styles (Future Enhancement)
The feature is designed to support different story styles:
- **Neutral**: Professional and informative tone
- **Humorous**: Engaging with light humor
- **For Children**: Simple language suitable for kids

*Note: Style selection UI will be added in a future update*

## Troubleshooting

### "LLM Not Configured" Dialog Appears
**Problem**: When you tap "AI Story", you see a dialog saying "LLM Not Configured"

**Solution**: 
1. Go to Settings
2. Find "AI Story Configuration" section
3. Enter your API key in the "API Key" field
4. Verify the green "LLM Configured" badge appears

### Story Generation Fails
**Problem**: Error message appears when generating story

**Possible causes and solutions**:

1. **Invalid API Key**
   - Verify your API key is correct
   - Check if the key has been revoked
   - Generate a new key from OpenAI platform

2. **Network Issues**
   - Check your internet connection
   - Verify the API endpoint is accessible
   - For local LLMs, ensure the server is running

3. **Rate Limiting**
   - OpenAI has rate limits on API calls
   - Wait a few moments and try again
   - Consider upgrading your OpenAI plan for higher limits

4. **Insufficient Credits**
   - Check your OpenAI account has available credits
   - Add payment method or credits to your account

### Story Not Playing Audio
**Problem**: Story appears but doesn't play

**Solution**:
1. Check device volume settings
2. Ensure TTS is enabled in device settings
3. Try tapping the "Play Again" button

## Cost Considerations

### OpenAI Pricing (as of 2024)
- **GPT-3.5-turbo**: ~$0.002 per 1,000 tokens (very affordable)
- **GPT-4**: ~$0.03 per 1,000 tokens (more expensive)
- Average story: 200-500 tokens (~$0.001 with GPT-3.5)

### Free Alternatives
Consider these free options:
- **Local LLMs** (LM Studio, Ollama): Completely free, runs on your computer
- **Free tier**: OpenAI offers $5 free credits for new accounts

## Privacy & Security

### What Data is Sent?
When you generate an AI story, the following is sent to the LLM API:
- POI name (e.g., "Eiffel Tower")
- POI description from Wikipedia
- System prompt for formatting

### What is NOT Sent?
- Your location
- Personal information
- App usage data
- Other POI data

### API Key Security
- Your API key is stored locally on your device
- It's never shared with anyone except the LLM API you configured
- The key field is masked in the UI for visual privacy

## Example Test Scenario

### Quick Test
1. **Configure**: Enter API key in Settings → AI Story Configuration
2. **Navigate**: Find a POI on the map (e.g., a museum or landmark)
3. **Open**: Tap the POI marker to open detail card
4. **Generate**: Tap the purple "AI Story" button
5. **Listen**: Wait for generation, then listen to the AI story

### Expected Result
- Loading indicator appears (3-10 seconds)
- AI-generated story appears in a styled container
- Story automatically plays through TTS
- You can tap "Play Again" to replay

## Tips for Best Results

1. **Choose interesting POIs**: Museums, landmarks, and historical sites generate better stories
2. **Wait for description**: Ensure the Wikipedia description loads before generating AI story
3. **Try different POIs**: Each generates a unique story based on the POI's description
4. **Good internet**: Fast connection means faster story generation
5. **GPT-4 for quality**: Use GPT-4 model for more detailed and accurate stories (costs more)

## Support

If you encounter issues not covered in this guide:
1. Check the app logs for error messages
2. Verify your API key and configuration
3. Test with a simple POI first
4. Open an issue on the GitHub repository

## Future Enhancements

Planned improvements:
- [ ] UI for selecting story style (neutral, humorous, for children)
- [ ] Story caching to reduce API calls
- [ ] Offline mode with pre-generated stories
- [ ] Support for more LLM providers
- [ ] Custom prompt templates
- [ ] Story history and favorites

---

**Happy exploring with AI-powered stories! 🎙️✨**
