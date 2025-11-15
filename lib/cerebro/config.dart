import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración de la API
class Config {
  // API Key desde variables de entorno (seguro)
  static String get openRouterApiKey =>
      dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static const String apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Modelo predeterminado (cambiado de Llama 3.2 a Gemma 2 por mejor rate limiting)
  static const String defaultModel = 'google/gemma-2-9b-it:free';

  // Clave de almacenamiento en SharedPreferences
  static const String _modelKey = 'selected_ai_model';

  // Timeout para las peticiones HTTP (en segundos)
  static const int httpTimeoutSeconds = 30;

  // Límite de caracteres en el input
  static const int maxInputCharacters = 500;

  /// Obtiene el modelo guardado en SharedPreferences
  /// Si no hay modelo guardado, devuelve el modelo predeterminado
  static Future<String> getSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString(_modelKey);

      if (savedModel != null && savedModel.isNotEmpty) {
        print('📦 Modelo cargado: $savedModel');
        return savedModel;
      }

      print('📦 Usando modelo predeterminado: $defaultModel');
      return defaultModel;
    } catch (e) {
      print('❌ Error al cargar modelo: $e');
      return defaultModel;
    }
  }

  /// Guarda el modelo seleccionado en SharedPreferences
  static Future<void> saveModel(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, modelId);
      print('💾 Modelo guardado: $modelId');
    } catch (e) {
      print('❌ Error al guardar modelo: $e');
    }
  }

  /// Obtiene el nombre amigable del modelo actual
  static Future<String> getCurrentModelName() async {
    final modelId = await getSavedModel();
    // Extraer nombre simple del ID
    final parts = modelId.split('/');
    if (parts.length > 1) {
      return parts.last.replaceAll('-instruct:free', '').replaceAll('-', ' ');
    }
    return modelId;
  }
}