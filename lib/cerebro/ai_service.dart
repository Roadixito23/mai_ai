import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mai_ai/cerebro/config.dart';
import 'package:mai_ai/cerebro/mai_personalidad.dart';

class AIService {
  // El modelo se actualizará dinámicamente antes de cada uso
  late GenerativeModel _client;
  String _currentModel = Config.defaultModel;

  // Constructor que inicializa el cliente con la clave API
  AIService() {
    _client = GenerativeModel(
      model: _currentModel,
      apiKey: Config.googleApiKey,
    );
  }

  // Método para actualizar el modelo antes de enviar mensajes
  Future<void> _updateClientModel() async {
    final modelId = await Config.getSavedModel();
    if (modelId != _currentModel) {
      _currentModel = modelId;
      // Recrear el cliente con el nuevo modelo
      _client = GenerativeModel(
        model: _currentModel,
        apiKey: Config.googleApiKey,
      );
    }
  }

  /// Convertir mensajes de formato interno a objetos Content del SDK
  List<Content> _convertToSDKFormat(List<Map<String, String>> messages) {
    List<Content> history = [];

    for (var message in messages) {
      // Ignorar mensajes 'system' ya que se manejan por separado
      if (message['role'] == 'system') continue;

      // Usar 'user' para el usuario, 'model' para el asistente
      final role = message['role'] == 'assistant' ? 'model' : 'user';
      history.add(
        Content(
          role,
          [TextPart(message['content']!)],
        ),
      );
    }
    return history;
  }

  /// Enviar mensaje usando Google Gemini con streaming (Implementación con SDK)
  Stream<String> sendMessageStream(List<Map<String, String>> messages) async* {
    if (Config.googleApiKey.isEmpty) {
      yield 'Error: La API key de Google está vacía. Revisa tu archivo .env';
      return;
    }

    try {
      await _updateClientModel(); // Asegura que el cliente usa el modelo seleccionado
      print('Usando modelo: $_currentModel (Vía SDK)');

      // Configurar la generación con los parámetros deseados
      final config = GenerationConfig(
        temperature: 0.9,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        // NO incluir systemInstruction aquí - no existe en GenerationConfig
      );

      // Recrear el cliente con la configuración
      _client = GenerativeModel(
        model: _currentModel,
        apiKey: Config.googleApiKey,
        generationConfig: config,
        // NO incluir systemInstruction aquí tampoco
      );

      // Convertir el historial al formato del SDK
      final history = _convertToSDKFormat(messages);

      // OPCIÓN 1: Incluir el system prompt como parte del primer mensaje del usuario
      // Esta es la forma más compatible con todas las versiones del SDK
      List<Content> finalHistory = [];

      if (history.isNotEmpty && history.first.role == 'user') {
        // Obtener el contenido del primer mensaje del usuario
        String userMessage = (history.first.parts.first as TextPart).text;

        // Combinar el system prompt con el mensaje del usuario
        String combinedMessage = '''
${MaiPersonalidad.systemPrompt}

Usuario: $userMessage''';

        // Crear un nuevo primer mensaje con ambos contenidos
        finalHistory.add(
          Content('user', [TextPart(combinedMessage)]),
        );

        // Agregar el resto del historial (sin el primer mensaje que ya modificamos)
        for (int i = 1; i < history.length; i++) {
          finalHistory.add(history[i]);
        }
      } else {
        // Si no hay mensajes o el primero no es del usuario, usar el historial tal cual
        finalHistory = history;
      }

      print('Enviando petición a Google con streaming...');

      // Usar el método de streaming del SDK
      final responseStream = _client.generateContentStream(finalHistory);

      // Procesar el stream del SDK con timeout
      await for (var chunk in responseStream.timeout(
        Duration(seconds: Config.httpTimeoutSeconds),
      )) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
      print('Streaming completado');
    } on TimeoutException {
      yield 'La conexión está tardando mucho. Verifica tu internet o intenta de nuevo.';
    } on GenerativeAIException catch (e) {
      // Manejo de errores específicos del SDK (incluye 404, 403, etc.)
      print('Error de API (SDK): ${e.message}');
      yield 'Error de la API: ${e.message}. Verifica tu clave y la disponibilidad del modelo.';
    } catch (e) {
      print('Error inesperado: $e');
      yield 'Error inesperado. Intenta de nuevo.';
    }
  }

  /// Enviar mensaje (sin streaming - fallback)
  /// Este método simplemente llama al stream y recolecta la respuesta.
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessageStream(messages)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}