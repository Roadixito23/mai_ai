import 'package:flutter_tts/flutter_tts.dart';
import '../modelos/voice_settings.dart';

/// Servicio para gestionar la conversión de texto a voz (TTS)
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  VoiceSettings _settings = VoiceSettings.defaults();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  TTSService() {
    _initialize();
  }

  /// Inicializar el servicio TTS con configuraciones predeterminadas
  Future<void> _initialize() async {
    try {
      // Configurar callbacks
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        print('Error TTS: $msg');
        _isSpeaking = false;
      });

      // Configurar parámetros iniciales
      await _applySettings(_settings);

      _isInitialized = true;
      print('TTS Service inicializado');
    } catch (e) {
      print('Error inicializando TTS: $e');
    }
  }

  /// Aplicar configuración de voz
  Future<void> _applySettings(VoiceSettings settings) async {
    try {
      await _flutterTts.setLanguage(settings.ttsLanguage);
      await _flutterTts.setSpeechRate(settings.speechRate);
      await _flutterTts.setVolume(settings.volume);
      await _flutterTts.setPitch(settings.pitch);

      // Configurar voz específica si está definida
      if (settings.preferredVoice != null) {
        await _flutterTts.setVoice({
          'name': settings.preferredVoice!,
          'locale': settings.ttsLanguage,
        });
      }
    } catch (e) {
      print('Error aplicando configuración TTS: $e');
    }
  }

  /// Actualizar la configuración de voz
  Future<void> updateSettings(VoiceSettings settings) async {
    if (!settings.isValid) {
      print('Configuración de voz inválida, usando valores predeterminados');
      return;
    }

    _settings = settings;
    await _applySettings(settings);
    print('Configuración TTS actualizada');
  }

  /// Convertir texto a voz
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      print('TTS no inicializado, inicializando...');
      await _initialize();
    }

    if (text.trim().isEmpty) {
      print('Texto vacío, no se puede reproducir');
      return;
    }

    try {
      // Detener cualquier reproducción anterior
      await stop();

      // Reproducir el nuevo texto
      await _flutterTts.speak(text);
      print('Reproduciendo texto (${text.length} caracteres)');
    } catch (e) {
      print('Error al reproducir texto: $e');
    }
  }

  /// Pausar la reproducción
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      print('TTS pausado');
    } catch (e) {
      print('Error al pausar TTS: $e');
    }
  }

  /// Detener la reproducción
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      print('TTS detenido');
    } catch (e) {
      print('Error al detener TTS: $e');
    }
  }

  /// Verificar si está hablando actualmente
  bool get isSpeaking => _isSpeaking;

  /// Obtener voces disponibles en el sistema
  Future<List<dynamic>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices ?? [];
    } catch (e) {
      print('Error obteniendo voces: $e');
      return [];
    }
  }

  /// Obtener idiomas disponibles
  Future<List<dynamic>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages ?? [];
    } catch (e) {
      print('Error obteniendo idiomas: $e');
      return [];
    }
  }

  /// Limpiar recursos
  void dispose() {
    stop();
  }
}
