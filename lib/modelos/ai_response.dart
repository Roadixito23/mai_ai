/// Modelo que representa una respuesta estructurada de la IA
class AIResponse {
  final String text;
  final String modelId;
  final DateTime timestamp;
  final int? tokensUsed;
  final int? responseTimeMs;
  final Map<String, dynamic>? metadata;
  final bool isError;
  final String? errorMessage;

  const AIResponse({
    required this.text,
    required this.modelId,
    required this.timestamp,
    this.tokensUsed,
    this.responseTimeMs,
    this.metadata,
    this.isError = false,
    this.errorMessage,
  });

  /// Crear una respuesta exitosa
  factory AIResponse.success({
    required String text,
    required String modelId,
    int? tokensUsed,
    int? responseTimeMs,
    Map<String, dynamic>? metadata,
  }) {
    return AIResponse(
      text: text,
      modelId: modelId,
      timestamp: DateTime.now(),
      tokensUsed: tokensUsed,
      responseTimeMs: responseTimeMs,
      metadata: metadata,
      isError: false,
    );
  }

  /// Crear una respuesta de error
  factory AIResponse.error({
    required String errorMessage,
    required String modelId,
  }) {
    return AIResponse(
      text: '',
      modelId: modelId,
      timestamp: DateTime.now(),
      isError: true,
      errorMessage: errorMessage,
    );
  }

  /// Verificar si la respuesta fue exitosa
  bool get isSuccess => !isError;

  /// Obtener el texto de la respuesta o el mensaje de error
  String get displayText => isError ? (errorMessage ?? 'Error desconocido') : text;

  /// Calcular tokens por segundo (si los datos están disponibles)
  double? get tokensPerSecond {
    if (tokensUsed != null && responseTimeMs != null && responseTimeMs! > 0) {
      return (tokensUsed! / (responseTimeMs! / 1000.0));
    }
    return null;
  }

  /// Crear una copia con valores actualizados
  AIResponse copyWith({
    String? text,
    String? modelId,
    DateTime? timestamp,
    int? tokensUsed,
    int? responseTimeMs,
    Map<String, dynamic>? metadata,
    bool? isError,
    String? errorMessage,
  }) {
    return AIResponse(
      text: text ?? this.text,
      modelId: modelId ?? this.modelId,
      timestamp: timestamp ?? this.timestamp,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      metadata: metadata ?? this.metadata,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'modelId': modelId,
      'timestamp': timestamp.toIso8601String(),
      'tokensUsed': tokensUsed,
      'responseTimeMs': responseTimeMs,
      'metadata': metadata,
      'isError': isError,
      'errorMessage': errorMessage,
    };
  }

  /// Crear desde JSON
  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      text: json['text'] as String,
      modelId: json['modelId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      tokensUsed: json['tokensUsed'] as int?,
      responseTimeMs: json['responseTimeMs'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isError: json['isError'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  String toString() {
    if (isError) {
      return 'AIResponse.error(model: $modelId, error: $errorMessage)';
    }
    return 'AIResponse(model: $modelId, tokens: $tokensUsed, time: ${responseTimeMs}ms)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIResponse &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          modelId == other.modelId &&
          timestamp == other.timestamp &&
          tokensUsed == other.tokensUsed &&
          responseTimeMs == other.responseTimeMs &&
          isError == other.isError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        text,
        modelId,
        timestamp,
        tokensUsed,
        responseTimeMs,
        isError,
        errorMessage,
      );
}
