import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const String gemini25Flash = 'gemini-2.5-flash';
  static const String gemini25Pro = 'gemini-2.5-pro';
  static const String gemini20Flash = 'gemini-2.0-flash';
  static const String gemini25FlashLite = 'gemini-2.5-flash-lite';

  static const String defaultModel = 'gemini-2.5-flash';

  static const String _modelKey = 'selected_ai_model';
  static const int httpTimeoutSeconds = 30;
  static const int maxInputCharacters = 500;

  /// Mensajes más recientes que se envían al modelo como contexto.
  static const int maxContextMessages = 30;

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

  static const Map<String, String> _modelNames = {
    gemini25Flash: 'Gemini 2.5 Flash',
    gemini25Pro: 'Gemini 2.5 Pro',
    gemini20Flash: 'Gemini 2.0 Flash',
    gemini25FlashLite: 'Gemini 2.5 Flash-Lite',
  };

  static Future<String> getSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedModel = prefs.getString(_modelKey);

      if (savedModel != null && savedModel.isNotEmpty) {
        final migrated = modelMigrationMap[savedModel];
        if (migrated != null) {
          debugPrint('Migrando modelo de $savedModel a $migrated');
          await saveModel(migrated);
          savedModel = migrated;
        }
        return savedModel;
      }
      return defaultModel;
    } catch (e) {
      debugPrint('Error al cargar modelo: $e');
      return defaultModel;
    }
  }

  static Future<void> saveModel(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelKey, modelId);
    } catch (e) {
      debugPrint('Error al guardar modelo: $e');
    }
  }

  static Future<String> getCurrentModelName() async {
    final modelId = await getSavedModel();
    return _modelNames[modelId] ?? modelId;
  }
}
