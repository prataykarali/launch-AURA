// chat_message.dart
// Simple immutable data model for a single chat message.
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool   isUser;

  const ChatMessage({required this.text, required this.isUser});
}