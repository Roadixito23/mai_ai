import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'mai_personalidad.dart';

class AIService {
  /// Convertir mensajes de formato OpenAI a formato Google Gemini
  Map<String, dynamic> _convertToGoogleFormat(List<Map<String, String>> messages) {
    // Separar system prompt de mensajes de usuario/asistente
    String systemPrompt = '';
    List<Map<String, dynamic>> contents = [];

    for (var message in messages) {
      if (message['role'] == 'system') {
        systemPrompt = message['content'] ?? '';
      } else {
        contents.add({
          'role': message['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': message['content']}
          ]
        });
      }
    }

    Map<String, dynamic> body = {
      'contents': contents,
    };

    // Agregar system instruction si existe
    if (systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    return body;
  }

  /// Enviar mensaje usando Google Gemini con streaming
  Stream<String> sendMessageStream(List<Map<String, String>> messages) async* {
    // Verificar API key
    final apiKey = Config.googleApiKey;
    if (apiKey.isEmpty) {
      print('❌ DEBUG ERROR: La API key de Google está VACÍA.');
      yield 'Error: La API key de Google está vacía. Revisa tu archivo .env';
      return;
    }

    try {
      final selectedModel = await Config.getSavedModel();
      print('🤖 Usando modelo: $selectedModel');
      print('🌐 Proveedor: Google Gemini (Streaming)');

      // Agregar personalidad de Mai
      List<Map<String, String>> messagesWithPersonality = [
        MaiPersonalidad.getSystemMessage(),
        ...messages,
      ];

      // Convertir al formato de Google
      final googleBody = _convertToGoogleFormat(messagesWithPersonality);

      print('📤 Enviando petición a Google con streaming...');

      // URL de streaming de Gemini
      final streamUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$selectedModel:streamGenerateContent?key=$apiKey&alt=sse';

      final request = http.Request('POST', Uri.parse(streamUrl));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(googleBody);

      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(
        Duration(seconds: Config.httpTimeoutSeconds),
        onTimeout: () {
          throw TimeoutException('La petición tardó demasiado tiempo');
        },
      );

      print('📡 Status Code: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
          // Procesar cada chunk del stream
          final lines = chunk.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              if (jsonStr.trim().isEmpty) continue;

              try {
                final data = jsonDecode(jsonStr);

                if (data['candidates'] != null && data['candidates'].isNotEmpty) {
                  final candidate = data['candidates'][0];
                  if (candidate['content'] != null &&
                      candidate['content']['parts'] != null &&
                      candidate['content']['parts'].isNotEmpty) {
                    final text = candidate['content']['parts'][0]['text'];
                    if (text != null && text.isNotEmpty) {
                      yield text;
                    }
                  }
                }
              } catch (e) {
                print('⚠️ Error al parsear chunk: $e');
              }
            }
          }
        }
        client.close();
        print('✅ Streaming completado');
      } else if (streamedResponse.statusCode == 400) {
        yield 'Error en la petición. Verifica la configuración.';
        client.close();
      } else if (streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) {
        yield 'Error de autenticación. Verifica tu API key de Google.';
        client.close();
      } else if (streamedResponse.statusCode == 404) {
        yield 'Modelo no encontrado. Verifica que el modelo esté disponible.';
        client.close();
      } else if (streamedResponse.statusCode == 429) {
        yield 'Demasiadas peticiones. Espera un momento.';
        client.close();
      } else if (streamedResponse.statusCode >= 500) {
        yield 'El servidor de Google está teniendo problemas. Intenta más tarde.';
        client.close();
      } else {
        yield 'Error ${streamedResponse.statusCode}. Intenta de nuevo.';
        client.close();
      }
    } on TimeoutException {
      yield 'La conexión está tardando mucho. Verifica tu internet.';
    } on http.ClientException {
      yield 'No pude conectarme al servidor. ¿Estás conectado a internet?';
    } catch (e) {
      print('❌ Error inesperado: $e');
      yield 'Error inesperado. Intenta de nuevo.';
    }
  }

  /// Enviar mensaje usando Google Gemini (sin streaming - fallback)
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    // Recolectar todo el stream en un solo string
    final buffer = StringBuffer();
    await for (final chunk in sendMessageStream(messages)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }
}
