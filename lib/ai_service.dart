import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class AIService {
  // Enviar mensaje al chatbot y obtener respuesta
  Future<String> sendMessage(List<Map<String, String>> messages) async {
    try {
      final response = await http.post(
        Uri.parse(Config.apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Config.openRouterApiKey}',
        },
        body: jsonEncode({
          'model': Config.model,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error al conectar con la IA: $e';
    }
  }
}
