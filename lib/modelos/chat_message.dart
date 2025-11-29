class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? modelId; // Modelo de IA usado para generar la respuesta
  final bool isError; // Indica si el mensaje es un error
  final Map<String, dynamic>? metadata; // Datos adicionales opcionales
  final int? tokensUsed; // Tokens usados (si es respuesta de IA)

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.modelId,
    this.isError = false,
    this.metadata,
    this.tokensUsed,
  })  : timestamp = timestamp ?? DateTime.now(),
        id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  /// Crear un mensaje del usuario
  factory ChatMessage.user({
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      text: text,
      isUser: true,
      metadata: metadata,
    );
  }

  /// Crear un mensaje de la IA
  factory ChatMessage.assistant({
    required String text,
    String? modelId,
    int? tokensUsed,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      text: text,
      isUser: false,
      modelId: modelId,
      tokensUsed: tokensUsed,
      metadata: metadata,
    );
  }

  /// Crear un mensaje de error
  factory ChatMessage.error({
    required String errorMessage,
    String? modelId,
  }) {
    return ChatMessage(
      text: errorMessage,
      isUser: false,
      modelId: modelId,
      isError: true,
    );
  }

  /// Crear una copia con valores actualizados
  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? modelId,
    bool? isError,
    Map<String, dynamic>? metadata,
    int? tokensUsed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      modelId: modelId ?? this.modelId,
      isError: isError ?? this.isError,
      metadata: metadata ?? this.metadata,
      tokensUsed: tokensUsed ?? this.tokensUsed,
    );
  }

  /// Verificar si el mensaje tiene contenido
  bool get hasContent => text.isNotEmpty;

  /// Obtener el rol del mensaje para la API
  String get role => isUser ? 'user' : 'assistant';

  // Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'isError': isError,
      'metadata': metadata,
      'tokensUsed': tokensUsed,
    };
  }

  // Crear desde JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      modelId: json['modelId'] as String?,
      isError: json['isError'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      tokensUsed: json['tokensUsed'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage(id: $id, isUser: $isUser, text: ${text.substring(0, text.length > 20 ? 20 : text.length)}...)';
  }
}
