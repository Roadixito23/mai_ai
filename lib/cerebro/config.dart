import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración de la API
class Config {
  // --- GOOGLE AI STUDIO (GEMINI) ---
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  // Modelos disponibles de Google (versiones estables)
  static const String geminiFlash = 'gemini-flash';
  static const String geminiPro = 'gemini-pro';

  // Modelo predeterminado
  static const String defaultModel = 'gemini-pro';

  // Construir URL con API key
  static String getGoogleApiUrl(String model) {
    return 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$googleApiKey';
  }

  // --- OPENROUTER (BACKUP) ---
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Configuración
  static const String currentProvider = 'google'; // 'google' o 'openrouter'
  static const String _modelKey = 'selected_ai_model';
  static const int httpTimeoutSeconds = 30;
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
    // Formatear nombre amigable
    if (modelId.contains('flash')) return 'Gemini Flash';
    if (modelId.contains('pro')) return 'Gemini Pro';
    return modelId;
  }
}