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

  /// Enviar mensaje usando Google Gemini
  Future<String> sendMessage(List<Map<String, String>> messages) async {

    // Verificar API key
    final apiKey = Config.googleApiKey;
    if (apiKey.isEmpty) {
      print('❌ DEBUG ERROR: La API key de Google está VACÍA.');
      return 'Error: La API key de Google está vacía. Revisa tu archivo .env';
    } else {
      print('✅ DEBUG: Google API Key cargada. Parcial: ${apiKey.substring(0, 6)}...${apiKey.substring(apiKey.length - 4)}');
    }

    try {
      final selectedModel = await Config.getSavedModel();
      print('🤖 Usando modelo: $selectedModel');
      print('🌐 Proveedor: Google Gemini');

      // Agregar personalidad de Mai
      List<Map<String, String>> messagesWithPersonality = [
        MaiPersonalidad.getSystemMessage(),
        ...messages,
      ];

      // Convertir al formato de Google
      final googleBody = _convertToGoogleFormat(messagesWithPersonality);

      print('📤 Enviando petición a Google...');

      final response = await http
          .post(
            Uri.parse(Config.getGoogleApiUrl(selectedModel)),
            headers: {
              'Content-Type': 'application/json',
              // NO incluir Authorization header - la key va en la URL
            },
            body: jsonEncode(googleBody),
          )
          .timeout(
            Duration(seconds: Config.httpTimeoutSeconds),
            onTimeout: () {
              throw TimeoutException('La petición tardó demasiado tiempo');
            },
          );

      print('📡 Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extraer respuesta del formato de Google
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            final text = candidate['content']['parts'][0]['text'];
            print('✅ Respuesta recibida correctamente');
            return text;
          }
        }

        print('❌ Formato de respuesta inesperado');
        print('📡 Response: ${response.body}');
        return 'Error: Formato de respuesta inesperado de Google';

      } else if (response.statusCode == 400) {
        print('📡 Error 400: ${response.body}');
        return 'Error en la petición. Verifica la configuración.';
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('📡 Error de autenticación: ${response.body}');
        return 'Error de autenticación. Verifica tu API key de Google.';
      } else if (response.statusCode == 429) {
        return 'Demasiadas peticiones. Espera un momento.';
      } else if (response.statusCode >= 500) {
        return 'El servidor de Google está teniendo problemas. Intenta más tarde.';
      } else {
        print('📡 Error desconocido: ${response.statusCode}');
        print('📡 Body: ${response.body}');
        return 'Error ${response.statusCode}. Intenta de nuevo.';
      }
    } on TimeoutException {
      return 'La conexión está tardando mucho. Verifica tu internet.';
    } on http.ClientException {
      return 'No pude conectarme al servidor. ¿Estás conectado a internet?';
    } catch (e) {
      print('❌ Error inesperado: $e');
      return 'Error inesperado. Intenta de nuevo.';
    }
  }
}
