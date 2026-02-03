import 'package:flutter_test/flutter_test.dart';
import 'package:passear/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('creates user message correctly', () {
      final message = ChatMessage.user('Hello, guide!');

      expect(message.content, equals('Hello, guide!'));
      expect(message.isUser, isTrue);
      expect(message.isError, isFalse);
      expect(message.id, isNotEmpty);
      expect(message.timestamp, isNotNull);
    });

    test('creates assistant message correctly', () {
      final message = ChatMessage.assistant('Hello! How can I help you?');

      expect(message.content, equals('Hello! How can I help you?'));
      expect(message.isUser, isFalse);
      expect(message.isError, isFalse);
      expect(message.id, isNotEmpty);
      expect(message.timestamp, isNotNull);
    });

    test('creates error message correctly', () {
      final message = ChatMessage.error('Something went wrong');

      expect(message.content, equals('Something went wrong'));
      expect(message.isUser, isFalse);
      expect(message.isError, isTrue);
      expect(message.id, isNotEmpty);
      expect(message.timestamp, isNotNull);
    });

    test('generates unique IDs for different messages', () {
      final message1 = ChatMessage.user('First message');
      final message2 = ChatMessage.user('Second message');

      expect(message1.id, isNot(equals(message2.id)));
    });
  });
}
