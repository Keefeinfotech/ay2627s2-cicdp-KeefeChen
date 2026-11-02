enum ChatRole { user, assistant }

/// A single message in the assistant conversation.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final ChatRole role;
  final String text;
  final bool isError;

  bool get isUser => role == ChatRole.user;
}
