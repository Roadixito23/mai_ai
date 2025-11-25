import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Configuración de la API
class Config {
  // --- GOOGLE AI STUDIO (GEMINI) ---
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  // Modelos disponibles de Google (versiones actuales - Enero 2025)
  static const String geminiFlash = 'gemini-1.5-flash';
  static const String geminiFlashLatest = 'gemini-1.5-flash-latest';
  static const String geminiPro = 'gemini-1.5-pro';
  static const String geminiProLatest = 'gemini-1.5-pro-latest';
  static const String gemini2Flash = 'gemini-2.0-flash-exp';

  // Modelo predeterminado (actualizado)
  static const String defaultModel = 'gemini-1.5-flash';

  // --- OPENROUTER (BACKUP) ---
  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Configuración
  static const String currentProvider = 'google'; // 'google' o 'openrouter'
  static const String _modelKey = 'selected_ai_model';
  static const int httpTimeoutSeconds = 30;
  static const int maxInputCharacters = 500;

  /// Mapa de migración de modelos antiguos a nuevos
  static const Map<String, String> modelMigrationMap = {
    'gemini-pro': 'gemini-1.5-pro',        // Modelo Pro anterior -> Pro actual
    'gemini-flash': 'gemini-1.5-flash',    // Flash anterior -> Flash actual
    'gemini-ultra': 'gemini-1.5-pro',      // Ultra anterior -> Pro actual
  };

  /// Obtiene el modelo guardado en SharedPreferences con migración automática
  static Future<String> getSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedModel = prefs.getString(_modelKey);

      // Si hay un modelo guardado, verificar si necesita migración
      if (savedModel != null && savedModel.isNotEmpty) {
        // Verificar si el modelo necesita migración
        if (modelMigrationMap.containsKey(savedModel)) {
          final newModel = modelMigrationMap[savedModel]!;
          print('📦 Migrando modelo de $savedModel a $newModel');
          await saveModel(newModel);
          savedModel = newModel;
        }

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
    if (modelId == 'gemini-1.5-flash') return 'Gemini 1.5 Flash';
    if (modelId == 'gemini-1.5-flash-latest') return 'Gemini 1.5 Flash (Última)';
    if (modelId == 'gemini-1.5-pro') return 'Gemini 1.5 Pro';
    if (modelId == 'gemini-1.5-pro-latest') return 'Gemini 1.5 Pro (Última)';
    if (modelId == 'gemini-2.0-flash-exp') return 'Gemini 2.0 Flash (Beta)';
    return modelId;
  }
}