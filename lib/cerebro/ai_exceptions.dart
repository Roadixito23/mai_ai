enum AIErrorKind { missingApiKey, invalidApiKey, timeout, network, api, unknown }

/// Error al hablar con el modelo. Se lanza en lugar de emitirse como texto
/// para que nunca termine mezclado con las respuestas reales de Mai.
class AIException implements Exception {
  final AIErrorKind kind;
  final String? detail;

  const AIException(this.kind, [this.detail]);

  bool get needsApiKey =>
      kind == AIErrorKind.missingApiKey || kind == AIErrorKind.invalidApiKey;

  String get userMessage {
    switch (kind) {
      case AIErrorKind.missingApiKey:
        return 'Todavía no tengo tu API key de Groq. Agrégala desde el menú para poder responderte.';
      case AIErrorKind.invalidApiKey:
        return 'Tu API key de Groq no es válida. Revísala desde el menú.';
      case AIErrorKind.timeout:
        return 'La conexión está tardando demasiado. Intenta de nuevo en un momento.';
      case AIErrorKind.network:
        return 'No pude conectarme. Revisa tu internet e intenta de nuevo.';
      case AIErrorKind.api:
        return 'La API respondió con un error${detail != null ? ': $detail' : ''}.';
      case AIErrorKind.unknown:
        return 'Algo salió mal. Intenta de nuevo.';
    }
  }

  @override
  String toString() => 'AIException($kind${detail != null ? ', $detail' : ''})';
}
