import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../datos/auth_service.dart';
import '../modelos/ai_model.dart';
import '../modelos/chat_message.dart';
import 'ai_exceptions.dart';
import 'api_key_store.dart';
import 'config.dart';
import 'herramientas.dart';
import 'mai_personalidad.dart';

/// Lo mínimo que el chat necesita de un modelo. Permite probar sin red.
abstract interface class ChatBackend {
  /// Emite el texto de la respuesta. [onAction] recibe un resumen de cada
  /// acción que el modelo ejecutó (crear tarea, iniciar timer...).
  Stream<String> sendMessageStream(
    List<ChatMessage> messages, {
    void Function(String resumen)? onAction,
  });
}

/// Convierte un audio en texto. Separado de [ChatBackend] para probar sin red.
abstract interface class Transcriber {
  Future<String> transcribe(String audioPath);
}

/// Dónde se llama a la API compatible con OpenAI y con qué cabeceras.
class AiEndpoint {
  const AiEndpoint(this.baseUrl, this.headers, {this.viaProxy = false});

  final String baseUrl;
  final Map<String, String> headers;

  /// true: Edge Function de Supabase con la sesión del dueño (la key de Groq
  /// vive en el servidor). false: Groq directo con la key de este dispositivo.
  final bool viaProxy;
}

class AIService implements ChatBackend, Transcriber {
  AIService({
    ApiKeyStore? keyStore,
    http.Client Function()? clientFactory,
    Herramientas? herramientas,
    Future<AiEndpoint> Function()? endpoint,
  })  : _keyStore = keyStore ?? ApiKeyStore(),
        _clientFactory = clientFactory ?? http.Client.new,
        _herramientas = herramientas,
        _endpointOverride = endpoint;

  final ApiKeyStore _keyStore;
  final http.Client Function() _clientFactory;
  final Future<AiEndpoint> Function()? _endpointOverride;

  /// Con sesión iniciada se usa el proxy; si no, la key local.
  Future<AiEndpoint> _endpoint() async {
    if (_endpointOverride != null) return _endpointOverride();
    final token = await AuthService.shared.accessToken();
    if (token != null) {
      return AiEndpoint(
        '${AuthService.url}/functions/v1/groq',
        {'Authorization': 'Bearer $token', 'apikey': AuthService.publishableKey},
        viaProxy: true,
      );
    }
    if (AuthService.configured) throw const AIException(AIErrorKind.sessionExpired);
    final apiKey = await _keyStore.read();
    if (apiKey.isEmpty) throw const AIException(AIErrorKind.missingApiKey);
    return AiEndpoint(Config.apiBaseUrl, {'Authorization': 'Bearer $apiKey'});
  }

  /// null: el modelo solo conversa, sin ejecutar acciones.
  final Herramientas? _herramientas;

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

  /// Vueltas máximas de herramientas por mensaje; la última se pide sin tools
  /// para que el modelo siempre termine respondiendo con texto.
  static const int _maxToolRounds = 4;

  @override
  Stream<String> sendMessageStream(
    List<ChatMessage> messages, {
    void Function(String resumen)? onAction,
  }) async* {
    final history = buildHistory(messages);
    if (history.isEmpty) return;

    final endpoint = await _endpoint();
    final client = _clientFactory();
    try {
      final model = await Config.getSavedModel();
      final now = DateTime.now();
      final recuerdos = _herramientas?.recuerdosParaPrompt() ?? const <String>[];
      final conversation = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': MaiPersonalidad.build(
            now,
            herramientas: _herramientas != null,
            recuerdos: recuerdos,
          ),
        },
        ...history,
      ];

      var toolsSupported = true;
      for (var round = 0; round < _maxToolRounds; round++) {
        final withTools =
            _herramientas != null && toolsSupported && round < _maxToolRounds - 1;
        final calls = <int, _ToolCall>{};
        final text = StringBuffer();

        try {
          await for (final chunk in _complete(client, endpoint, {
            'model': model,
            'stream': true,
            'temperature': 0.9,
            'top_p': 0.95,
            'messages': conversation,
            if (withTools) 'tools': _herramientas.esquemas,
          }, calls)) {
            text.write(chunk);
            yield chunk;
          }
        } on AIException catch (e) {
          // Algunos modelos no aceptan herramientas: se responde solo con texto.
          if (!withTools || text.isNotEmpty || !_isToolsUnsupported(e)) rethrow;
          debugPrint('El modelo $model no admite herramientas; se sigue sin ellas.');
          toolsSupported = false;
          conversation[0] = {
            'role': 'system',
            'content': MaiPersonalidad.build(now, herramientas: false, recuerdos: recuerdos),
          };
          round--;
          continue;
        }

        if (calls.isEmpty) return;

        final ordered = (calls.keys.toList()..sort()).map((i) => calls[i]!).toList();
        conversation.add({
          'role': 'assistant',
          'content': text.isEmpty ? null : text.toString(),
          'tool_calls': [for (final c in ordered) c.toJson()],
        });
        for (final call in ordered) {
          final result = await _herramientas!.ejecutar(call.name, call.arguments.toString());
          if (result.resumen != null) onAction?.call(result.resumen!);
          conversation.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'content': jsonEncode(result.json),
          });
        }
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

  /// Una petición en streaming: emite el texto y acumula en [calls] las
  /// llamadas a herramientas, que llegan en fragmentos indexados.
  Stream<String> _complete(
    http.Client client,
    AiEndpoint endpoint,
    Map<String, dynamic> body,
    Map<int, _ToolCall> calls,
  ) async* {
    final request = http.Request('POST', Uri.parse('${endpoint.baseUrl}/chat/completions'))
      ..headers.addAll({...endpoint.headers, 'Content-Type': 'application/json'})
      ..body = jsonEncode(body);

    final response = await client
        .send(request)
        .timeout(Duration(seconds: Config.httpTimeoutSeconds));

    if (response.statusCode != 200) {
      final text = await response.stream.bytesToString();
      throw _errorFor(response.statusCode, text, viaProxy: endpoint.viaProxy);
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
      if (choices == null || choices.isEmpty) continue;
      final delta = choices.first['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      for (final raw in (delta['tool_calls'] as List?) ?? const []) {
        final index = raw['index'] as int? ?? 0;
        final call = calls.putIfAbsent(index, _ToolCall.new);
        call.id = raw['id'] as String? ?? call.id;
        final fn = raw['function'] as Map<String, dynamic>?;
        call.name = fn?['name'] as String? ?? call.name;
        call.arguments.write(fn?['arguments'] as String? ?? '');
      }

      final text = delta['content'] as String?;
      if (text != null && text.isNotEmpty) yield text;
    }
  }

  static const String transcriptionModel = 'whisper-large-v3-turbo';

  /// Transcribe la voz del usuario con Whisper (vía el proxy si hay sesión).
  @override
  Future<String> transcribe(String audioPath) async {
    final endpoint = await _endpoint();
    final client = _clientFactory();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${endpoint.baseUrl}/audio/transcriptions'),
      )
        ..headers.addAll(endpoint.headers)
        ..fields['model'] = transcriptionModel
        ..fields['language'] = 'es'
        ..fields['response_format'] = 'json'
        ..files.add(await http.MultipartFile.fromPath('file', audioPath));

      final response = await http.Response.fromStream(
        await client.send(request).timeout(Duration(seconds: Config.httpTimeoutSeconds)),
      );
      if (response.statusCode != 200) {
        throw _errorFor(response.statusCode, response.body, viaProxy: endpoint.viaProxy);
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (json['text'] as String? ?? '').trim();
    } on TimeoutException {
      throw const AIException(AIErrorKind.timeout);
    } on http.ClientException {
      throw const AIException(AIErrorKind.network);
    } on AIException {
      rethrow;
    } catch (e) {
      debugPrint('Error al transcribir: $e');
      throw AIException(AIErrorKind.unknown, e.toString());
    } finally {
      client.close();
    }
  }

  /// Ids que no sirven para chat (voz, moderación, embeddings).
  static final _nonChatModel = RegExp(r'whisper|orpheus|playai|tts|guard|embed|safeguard');

  /// Modelos de chat que la API key actual puede usar.
  Future<List<AIModel>> listModels() async {
    final endpoint = await _endpoint();
    final client = _clientFactory();
    try {
      final response = await client
          .get(Uri.parse('${endpoint.baseUrl}/models'), headers: endpoint.headers)
          .timeout(Duration(seconds: Config.httpTimeoutSeconds));

      if (response.statusCode != 200) {
        throw _errorFor(response.statusCode, response.body, viaProxy: endpoint.viaProxy);
      }

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

  static bool _isToolsUnsupported(AIException e) =>
      e.kind == AIErrorKind.api && (e.detail ?? '').contains('tool calling');

  static AIException _errorFor(int status, String body, {bool viaProxy = false}) {
    if (status == 401) {
      // Por el proxy, 401 es la sesión de Supabase; la key de Groq es del servidor.
      return AIException(viaProxy ? AIErrorKind.sessionExpired : AIErrorKind.invalidApiKey);
    }
    String? message;
    try {
      message = (jsonDecode(body)['error']?['message']) as String?;
    } catch (_) {}
    debugPrint('Error de la API de Groq ($status): ${message ?? body}');
    return AIException(AIErrorKind.api, message);
  }
}

/// Llamada a herramienta que se va armando con los fragmentos del streaming.
class _ToolCall {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': arguments.toString()},
      };
}
