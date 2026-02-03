/// Model for chat messages in the AI guide chat
class ChatMessage {
  static int _counter = 0;

  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });

  /// Generate a unique ID using timestamp and counter
  static String _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = _counter++;
    return '${timestamp}_$counter';
  }

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: _generateUniqueId(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: _generateUniqueId(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.error(String content) {
    return ChatMessage(
      id: _generateUniqueId(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    );
  }
}
