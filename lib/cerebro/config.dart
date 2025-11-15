import 'package:flutter_dotenv/flutter_dotenv.dart';

// Configuración de la API
class Config {
  // API Key desde variables de entorno (seguro)
  static String get openRouterApiKey =>
      dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Modelo a usar (puedes cambiarlo por otro disponible en OpenRouter)
  static const String model = 'meta-llama/llama-3.2-3b-instruct:free';

  // Timeout para las peticiones HTTP (en segundos)
  static const int httpTimeoutSeconds = 30;

  // Límite de caracteres en el input
  static const int maxInputCharacters = 500;
}