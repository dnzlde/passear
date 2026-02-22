import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/chat_message.dart';
import '../models/poi.dart';
import '../services/guide_chat_service.dart';
import '../services/tts_service.dart';

/// Widget for the AI guide chat interface
class GuideChatPage extends StatefulWidget {
  final LatLng userLocation;
  final GuideChatService chatService;
  final TtsService? ttsService;
  final Poi? referencePoi;

  const GuideChatPage({
    super.key,
    required this.userLocation,
    required this.chatService,
    this.ttsService,
    this.referencePoi,
  });

  @override
  State<GuideChatPage> createState() => _GuideChatPageState();
}

class _GuideChatPageState extends State<GuideChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message with optional POI reference
    String welcomeMessage =
        'Hello! I\'m your AI guide. Ask me anything about the nearby places!';
    if (widget.referencePoi != null) {
      welcomeMessage =
          'Hello! I\'m your AI guide. You can ask me about ${widget.referencePoi!.name} or other nearby places!';
    }
    _messages.add(ChatMessage.assistant(welcomeMessage));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _stopAudio();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage.user(text));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Get response from guide
    try {
      final response = await widget.chatService.askGuide(
        question: text,
        userLocation: widget.userLocation,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage.assistant(response));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } on GuideChatException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage.error(e.message));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage.error(
              'An unexpected error occurred. Please try again.',
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _playAudio(String text) async {
    if (widget.ttsService == null) return;

    if (_isPlayingAudio) {
      await _stopAudio();
      return;
    }

    setState(() {
      _isPlayingAudio = true;
    });

    try {
      await widget.ttsService!.speak(text);
    } finally {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    }
  }

  Future<void> _stopAudio() async {
    if (widget.ttsService != null) {
      await widget.ttsService!.stop();
    }
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask the Guide'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Ask me anything about nearby places!'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Thinking...'),
                ],
              ),
            ),

          // Input field
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about nearby places...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor:
                  isError ? Colors.red : Theme.of(context).colorScheme.primary,
              child: Icon(
                isError ? Icons.error : Icons.support_agent,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : isError
                        ? Colors.red.shade50
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : isError
                              ? Colors.red.shade900
                              : Colors.black87,
                    ),
                  ),
                  if (!isUser && !isError && widget.ttsService != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlayingAudio ? Icons.stop : Icons.volume_up,
                            size: 20,
                          ),
                          onPressed: () => _playAudio(message.content),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
