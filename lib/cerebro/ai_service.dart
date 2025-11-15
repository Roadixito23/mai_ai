import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'mai_personalidad.dart';

class AIService {
  // Enviar mensaje al chatbot y obtener respuesta
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    try {
      // Agregar el mensaje de sistema con la personalidad de MAI al inicio
      List<Map<String, String>> messagesWithPersonality = [
        MaiPersonalidad.getSystemMessage(),
        ...messages,
      ];

      final response = await http
          .post(
            Uri.parse(Config.apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Config.openRouterApiKey}',
            },
            body: jsonEncode({
              'model': Config.model,
              'messages': messagesWithPersonality,
            }),
          )
          .timeout(
            Duration(seconds: Config.httpTimeoutSeconds),
            onTimeout: () {
              throw TimeoutException(
                'La petición tardó demasiado tiempo',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else if (response.statusCode == 401) {
        return 'Oops, parece que hay un problema con la autenticación. Verifica tu API key.';
      } else if (response.statusCode == 429) {
        return 'Hey, estamos recibiendo demasiadas peticiones. Espera un momento y vuelve a intentar.';
      } else if (response.statusCode >= 500) {
        return 'Uf, parece que el servidor está teniendo problemas. Intenta de nuevo en unos minutos.';
      } else {
        return 'Hmm, algo salió mal (código: ${response.statusCode}). ¿Puedes intentar de nuevo?';
      }
    } on TimeoutException {
      return 'Oye, la conexión está tardando mucho. Verifica tu internet e intenta de nuevo.';
    } on http.ClientException {
      return 'No pude conectarme al servidor. ¿Estás conectado a internet?';
    } catch (e) {
      return 'Ups, ocurrió un error inesperado. Intenta de nuevo en un momento.';
    }
  }
}
