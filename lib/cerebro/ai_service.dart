import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../modelos/chat_message.dart';
import 'ai_exceptions.dart';
import 'api_key_store.dart';
import 'config.dart';
import 'mai_personalidad.dart';

/// Lo mínimo que el chat necesita de un modelo. Permite probar sin red.
abstract interface class ChatBackend {
  Stream<String> sendMessageStream(List<ChatMessage> messages);
}

class AIService implements ChatBackend {
  AIService({ApiKeyStore? keyStore}) : _keyStore = keyStore ?? ApiKeyStore();

  final ApiKeyStore _keyStore;

  GenerativeModel? _client;
  String? _clientModel;
  String? _clientKey;

  static final _generationConfig = GenerationConfig(
    temperature: 0.9,
    topK: 40,
    topP: 0.95,
    maxOutputTokens: 8192,
  );

  /// Reutiliza el cliente mientras no cambien ni el modelo ni la key.
  Future<GenerativeModel> _clientFor(String model, String apiKey) async {
    if (_client == null || _clientModel != model || _clientKey != apiKey) {
      _client = GenerativeModel(
        model: model,
        apiKey: apiKey,
        generationConfig: _generationConfig,
        systemInstruction: Content.system(MaiPersonalidad.systemPrompt),
      );
      _clientModel = model;
      _clientKey = apiKey;
    }
    return _client!;
  }

  /// Convierte el historial del chat al formato del SDK.
  ///
  /// Descarta errores y mensajes vacíos, se queda con los más recientes y
  /// garantiza que la conversación empiece con un mensaje del usuario.
  @visibleForTesting
  static List<Content> buildHistory(
    List<ChatMessage> messages, {
    int maxMessages = Config.maxContextMessages,
  }) {
    var valid = messages.where((m) => !m.isError && m.text.trim().isNotEmpty).toList();
    if (valid.length > maxMessages) {
      valid = valid.sublist(valid.length - maxMessages);
    }
    while (valid.isNotEmpty && !valid.first.isUser) {
      valid.removeAt(0);
    }
    return [
      for (final m in valid)
        Content(m.isUser ? 'user' : 'model', [TextPart(m.text)]),
    ];
  }

  @override
  Stream<String> sendMessageStream(List<ChatMessage> messages) async* {
    final apiKey = await _keyStore.read();
    if (apiKey.isEmpty) throw const AIException(AIErrorKind.missingApiKey);

    final history = buildHistory(messages);
    if (history.isEmpty) return;

    try {
      final model = await _clientFor(await Config.getSavedModel(), apiKey);
      final stream = model.generateContentStream(history).timeout(
            Duration(seconds: Config.httpTimeoutSeconds),
          );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) yield text;
      }
    } on TimeoutException {
      throw const AIException(AIErrorKind.timeout);
    } on InvalidApiKey {
      throw const AIException(AIErrorKind.invalidApiKey);
    } on GenerativeAIException catch (e) {
      debugPrint('Error de la API de Gemini: ${e.message}');
      throw AIException(AIErrorKind.api, e.message);
    } on http.ClientException {
      throw const AIException(AIErrorKind.network);
    } on AIException {
      rethrow;
    } catch (e) {
      debugPrint('Error inesperado en AIService: $e');
      throw AIException(AIErrorKind.unknown, e.toString());
    }
  }
}
