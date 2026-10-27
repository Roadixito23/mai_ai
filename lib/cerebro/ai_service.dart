import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../modelos/ai_model.dart';
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
  AIService({ApiKeyStore? keyStore, http.Client Function()? clientFactory})
      : _keyStore = keyStore ?? ApiKeyStore(),
        _clientFactory = clientFactory ?? http.Client.new;

  final ApiKeyStore _keyStore;
  final http.Client Function() _clientFactory;

  /// Convierte el historial del chat al formato de la API (compatible con OpenAI).
  ///
  /// Descarta errores y mensajes vacíos, se queda con los más recientes y
  /// garantiza que la conversación empiece con un mensaje del usuario.
  @visibleForTesting
  static List<Map<String, String>> buildHistory(
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
        {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
    ];
  }

  @override
  Stream<String> sendMessageStream(List<ChatMessage> messages) async* {
    final apiKey = await _keyStore.read();
    if (apiKey.isEmpty) throw const AIException(AIErrorKind.missingApiKey);

    final history = buildHistory(messages);
    if (history.isEmpty) return;

    final client = _clientFactory();
    try {
      final request = http.Request('POST', Uri.parse('${Config.apiBaseUrl}/chat/completions'))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'model': await Config.getSavedModel(),
          'stream': true,
          'temperature': 0.9,
          'top_p': 0.95,
          'messages': [
            {'role': 'system', 'content': MaiPersonalidad.systemPrompt},
            ...history,
          ],
        });

      final response = await client
          .send(request)
          .timeout(Duration(seconds: Config.httpTimeoutSeconds));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw _errorFor(response.statusCode, body);
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(Duration(seconds: Config.httpTimeoutSeconds));
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') break;
        final choices = (jsonDecode(data) as Map<String, dynamic>)['choices'] as List?;
        final text = choices == null || choices.isEmpty
            ? null
            : (choices.first['delta'] as Map<String, dynamic>?)?['content'] as String?;
        if (text != null && text.isNotEmpty) yield text;
      }
    } on TimeoutException {
      throw const AIException(AIErrorKind.timeout);
    } on http.ClientException {
      throw const AIException(AIErrorKind.network);
    } on AIException {
      rethrow;
    } catch (e) {
      debugPrint('Error inesperado en AIService: $e');
      throw AIException(AIErrorKind.unknown, e.toString());
    } finally {
      client.close();
    }
  }

  /// Ids que no sirven para chat (voz, moderación, embeddings).
  static final _nonChatModel = RegExp(r'whisper|orpheus|playai|tts|guard|embed|safeguard');

  /// Modelos de chat que la API key actual puede usar.
  Future<List<AIModel>> listModels() async {
    final apiKey = await _keyStore.read();
    if (apiKey.isEmpty) throw const AIException(AIErrorKind.missingApiKey);

    final client = _clientFactory();
    try {
      final response = await client.get(
        Uri.parse('${Config.apiBaseUrl}/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(Duration(seconds: Config.httpTimeoutSeconds));

      if (response.statusCode != 200) throw _errorFor(response.statusCode, response.body);

      final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'] as List;
      final ids = [
        for (final m in data)
          if (m['active'] != false && !_nonChatModel.hasMatch(m['id'] as String))
            m['id'] as String,
      ]..sort();
      return [for (final id in ids) AIModel.fromId(id)];
    } on TimeoutException {
      throw const AIException(AIErrorKind.timeout);
    } on http.ClientException {
      throw const AIException(AIErrorKind.network);
    } on AIException {
      rethrow;
    } catch (e) {
      debugPrint('Error al listar modelos: $e');
      throw AIException(AIErrorKind.unknown, e.toString());
    } finally {
      client.close();
    }
  }

  static AIException _errorFor(int status, String body) {
    if (status == 401) return const AIException(AIErrorKind.invalidApiKey);
    String? message;
    try {
      message = (jsonDecode(body)['error']?['message']) as String?;
    } catch (_) {}
    debugPrint('Error de la API de Groq ($status): ${message ?? body}');
    return AIException(AIErrorKind.api, message);
  }
}
