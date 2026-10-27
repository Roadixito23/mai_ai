import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static const String llama33Versatile = 'llama-3.3-70b-versatile';
  static const String llama31Instant = 'llama-3.1-8b-instant';
  static const String gptOss120b = 'openai/gpt-oss-120b';
  static const String gptOss20b = 'openai/gpt-oss-20b';

  static const String defaultModel = gptOss120b;

  static const String apiBaseUrl = 'https://api.groq.com/openai/v1';

  static const String _modelKey = 'selected_ai_model';
  static const int httpTimeoutSeconds = 30;
  static const int maxInputCharacters = 500;

  /// Mensajes más recientes que se envían al modelo como contexto.
  static const int maxContextMessages = 30;

  /// Los ids de Gemini guardados antes del cambio a Groq caen al modelo por defecto.
  static bool _isLegacyModel(String id) => id.startsWith('gemini');

  static const Map<String, String> _modelNames = {
    llama33Versatile: 'Llama 3.3 70B',
    llama31Instant: 'Llama 3.1 8B Instant',
    gptOss120b: 'GPT-OSS 120B',
    gptOss20b: 'GPT-OSS 20B',
  };

  static Future<String> getSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedModel = prefs.getString(_modelKey);

      if (savedModel != null && savedModel.isNotEmpty) {
        if (_isLegacyModel(savedModel)) {
          debugPrint('Migrando modelo de $savedModel a $defaultModel');
          await saveModel(defaultModel);
          return defaultModel;
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
