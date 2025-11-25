import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static String get googleApiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  // ✅ MODELOS ACTUALIZADOS (Noviembre 2025)
  static const String gemini25Flash = 'gemini-2.5-flash';
  static const String gemini25Pro = 'gemini-2.5-pro';
  static const String gemini20Flash = 'gemini-2.0-flash';
  static const String gemini25FlashLite = 'gemini-2.5-flash-lite';

  // ✅ Modelo predeterminado ACTUALIZADO
  static const String defaultModel = 'gemini-2.5-flash';

  static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  static const String openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String currentProvider = 'google';
  static const String _modelKey = 'selected_ai_model';
  static const int httpTimeoutSeconds = 30;
  static const int maxInputCharacters = 500;

  // ✅ Mapa de migración ACTUALIZADO
  static const Map<String, String> modelMigrationMap = {
    'gemini-pro': 'gemini-2.5-pro',
    'gemini-1.5-pro': 'gemini-2.5-pro',
    'gemini-1.5-pro-latest': 'gemini-2.5-pro',
    'gemini-flash': 'gemini-2.5-flash',
    'gemini-1.5-flash': 'gemini-2.5-flash',
    'gemini-1.5-flash-latest': 'gemini-2.5-flash',
    'gemini-ultra': 'gemini-2.5-pro',
    'gemini-2.0-flash-exp': 'gemini-2.0-flash',
  };

  static Future<String> getSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedModel = prefs.getString(_modelKey);

      if (savedModel != null && savedModel.isNotEmpty) {
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

  static Future<void> saveModel(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, modelId);
      print('💾 Modelo guardado: $modelId');
    } catch (e) {
      print('❌ Error al guardar modelo: $e');
    }
  }

  // ✅ Nombres amigables ACTUALIZADOS
  static Future<String> getCurrentModelName() async {
    final modelId = await getSavedModel();
    if (modelId == 'gemini-2.5-flash') return 'Gemini 2.5 Flash ⚡';
    if (modelId == 'gemini-2.5-pro') return 'Gemini 2.5 Pro 🚀';
    if (modelId == 'gemini-2.0-flash') return 'Gemini 2.0 Flash';
    if (modelId == 'gemini-2.5-flash-lite') return 'Gemini 2.5 Flash-Lite';
    return modelId;
  }
}