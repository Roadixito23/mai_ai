import 'chat_message.dart';

/// Modelo que representa una conversación completa con Mai
class Conversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String modelId;
  final bool isPinned;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.modelId,
    this.isPinned = false,
  });

  /// Crear una nueva conversación
  factory Conversation.create({
    required String title,
    String? modelId,
  }) {
    final now = DateTime.now();
    return Conversation(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      messages: [],
      createdAt: now,
      updatedAt: now,
      modelId: modelId ?? 'gemini-2.5-flash',
      isPinned: false,
    );
  }

  /// Crear una copia de la conversación con valores actualizados
  Conversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? modelId,
    bool? isPinned,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modelId: modelId ?? this.modelId,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  /// Agregar un mensaje a la conversación
  Conversation addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: DateTime.now(),
    );
  }

  /// Obtener el número total de mensajes
  int get messageCount => messages.length;

  /// Obtener el último mensaje de la conversación
  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Verificar si la conversación está vacía
  bool get isEmpty => messages.isEmpty;

  /// Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'modelId': modelId,
      'isPinned': isPinned,
    };
  }

  /// Crear desde JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      modelId: json['modelId'] as String,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
