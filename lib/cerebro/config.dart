// Configuración de la API
class Config {
  // API Key de OpenRouter
  static const String openRouterApiKey = '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';
  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Modelo a usar (puedes cambiarlo por otro disponible en OpenRouter)
  static const String model = 'meta-llama/llama-3.2-3b-instruct:free';

  // Timeout para las peticiones HTTP (en segundos)
  static const int httpTimeoutSeconds = 30;

  // Límite de caracteres en el input
  static const int maxInputCharacters = 500;
}
