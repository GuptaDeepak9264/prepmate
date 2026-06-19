import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant, system }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        content: map['content'] as String? ?? '',
        role: MessageRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => MessageRole.user,
        ),
        timestamp: map['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'role': role.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  // API format (for sending to AI)
  Map<String, String> toApiMessage() => {
        'role': role == MessageRole.assistant ? 'assistant' : 'user',
        'content': content,
      };

  @override
  List<Object?> get props => [id, content, role, timestamp];
}

class ChatSession extends Equatable {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  String get lastMessagePreview => messages.isNotEmpty
      ? messages.last.content.length > 60
          ? '${messages.last.content.substring(0, 60)}...'
          : messages.last.content
      : 'New conversation';

  factory ChatSession.fromMap(Map<String, dynamic> map, String id) =>
      ChatSession(
        id: id,
        title: map['title'] as String? ?? 'Chat',
        messages: (map['messages'] as List<dynamic>? ?? [])
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList(),
        createdAt: map['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'messages': messages.map((m) => m.toMap()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [id, title, messages.length, updatedAt];
}
