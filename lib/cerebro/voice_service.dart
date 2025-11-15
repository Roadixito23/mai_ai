import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servicio para manejar reconocimiento de voz (Speech-to-Text)
/// y síntesis de voz (Text-to-Speech) en español
class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  // Callbacks para comunicarse con la UI
  Function(String)? onTextRecognized;
  Function(bool)? onListeningStateChanged;
  Function(bool)? onSpeakingStateChanged;
  Function(String)? onError;

  /// Obtiene el estado de inicialización del servicio
  bool get isInitialized => _isInitialized;

  /// Obtiene el estado de escucha
  bool get isListening => _isListening;

  /// Obtiene el estado de habla
  bool get isSpeaking => _isSpeaking;

  /// Inicializa los servicios de voz (STT y TTS)
  Future<bool> initialize() async {
    try {
      print('🎤 Inicializando servicio de voz...');

      // Inicializar Speech-to-Text
      bool sttAvailable = await _speechToText.initialize(
        onError: (error) {
          print('❌ Error en STT: ${error.errorMsg}');
          onError?.call('Error de reconocimiento: ${error.errorMsg}');
          _isListening = false;
          onListeningStateChanged?.call(false);
        },
        onStatus: (status) {
          print('📊 Estado STT: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            onListeningStateChanged?.call(false);
          } else if (status == 'listening') {
            _isListening = true;
            onListeningStateChanged?.call(true);
          }
        },
      );

      if (!sttAvailable) {
        print('❌ Speech-to-Text no está disponible');
        onError?.call('El reconocimiento de voz no está disponible en este dispositivo');
        return false;
      }

      // Configurar Text-to-Speech
      await _configurarTTS();

      _isInitialized = true;
      print('✅ Servicio de voz inicializado correctamente');
      return true;
    } catch (e) {
      print('❌ Error al inicializar servicio de voz: $e');
      onError?.call('Error al inicializar el servicio de voz: $e');
      return false;
    }
  }

  /// Configura el servicio de Text-to-Speech
  Future<void> _configurarTTS() async {
    try {
      // Configurar idioma a español
      await _flutterTts.setLanguage('es-ES');

      // Configurar velocidad de habla (0.0 - 1.0, recomendado 0.5)
      await _flutterTts.setSpeechRate(0.5);

      // Configurar volumen (0.0 - 1.0)
      await _flutterTts.setVolume(1.0);

      // Configurar tono de voz (0.5 - 2.0, 1.0 es normal)
      await _flutterTts.setPitch(1.0);

      // Configurar callbacks de TTS
      _flutterTts.setStartHandler(() {
        print('🗣️ Mai está hablando...');
        _isSpeaking = true;
        onSpeakingStateChanged?.call(true);
      });

      _flutterTts.setCompletionHandler(() {
        print('✅ Mai terminó de hablar');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      _flutterTts.setErrorHandler((msg) {
        print('❌ Error en TTS: $msg');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        onError?.call('Error al hablar: $msg');
      });

      print('✅ TTS configurado en español');
    } catch (e) {
      print('❌ Error al configurar TTS: $e');
      onError?.call('Error al configurar la voz: $e');
    }
  }

  /// Inicia el reconocimiento de voz
  Future<void> startListening() async {
    if (!_isInitialized) {
      print('⚠️ Servicio de voz no inicializado');
      onError?.call('El servicio de voz no está inicializado');
      return;
    }

    if (_isListening) {
      print('⚠️ Ya está escuchando');
      return;
    }

    try {
      print('🎤 Iniciando escucha...');

      // Obtener idiomas disponibles
      List<LocaleName> locales = await _speechToText.locales();
      print('📋 Idiomas disponibles: ${locales.length}');

      // Buscar locale español
      LocaleName? spanishLocale;
      for (var locale in locales) {
        if (locale.localeId.startsWith('es')) {
          spanishLocale = locale;
          print('✅ Usando idioma: ${locale.localeId} - ${locale.name}');
          break;
        }
      }

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            String texto = result.recognizedWords;
            print('🎯 Texto reconocido: $texto');
            if (texto.isNotEmpty) {
              onTextRecognized?.call(texto);
            }
          } else {
            print('⏳ Reconociendo: ${result.recognizedWords}');
          }
        },
        localeId: spanishLocale?.localeId ?? 'es-ES',
        listenMode: ListenMode.confirmation,
        partialResults: true,
        onSoundLevelChange: (level) {
          // Opcional: usar para mostrar niveles de sonido
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );

      _isListening = true;
      onListeningStateChanged?.call(true);
      print('✅ Escucha iniciada');
    } catch (e) {
      print('❌ Error al iniciar escucha: $e');
      onError?.call('Error al iniciar el reconocimiento: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
    }
  }

  /// Detiene el reconocimiento de voz
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      print('🛑 Deteniendo escucha...');
      await _speechToText.stop();
      _isListening = false;
      onListeningStateChanged?.call(false);
      print('✅ Escucha detenida');
    } catch (e) {
      print('❌ Error al detener escucha: $e');
      onError?.call('Error al detener el reconocimiento: $e');
    }
  }

  /// Hace que Mai hable el texto proporcionado
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      print('⚠️ Servicio de voz no inicializado');
      onError?.call('El servicio de voz no está inicializado');
      return;
    }

    if (text.trim().isEmpty) {
      print('⚠️ Texto vacío, no hay nada que decir');
      return;
    }

    try {
      // Si ya está hablando, detener primero
      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      // Si está escuchando, detener primero
      if (_isListening) {
        await stopListening();
      }

      print('🗣️ Mai va a decir: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      await _flutterTts.speak(text);
    } catch (e) {
      print('❌ Error al hablar: $e');
      onError?.call('Error al reproducir voz: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    }
  }

  /// Detiene la reproducción de voz
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      try {
        print('🛑 Deteniendo voz de Mai...');
        await _flutterTts.stop();
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
        print('✅ Voz detenida');
      } catch (e) {
        print('❌ Error al detener voz: $e');
      }
    }
  }

  /// Verifica si el micrófono tiene permisos
  Future<bool> checkMicrophonePermission() async {
    try {
      bool hasPermission = await _speechToText.hasPermission;
      print(hasPermission
        ? '✅ Permisos de micrófono otorgados'
        : '❌ No hay permisos de micrófono');
      return hasPermission;
    } catch (e) {
      print('❌ Error al verificar permisos: $e');
      return false;
    }
  }

  /// Obtiene la lista de idiomas disponibles para STT
  Future<List<LocaleName>> getAvailableLocales() async {
    try {
      List<LocaleName> locales = await _speechToText.locales();
      print('📋 ${locales.length} idiomas disponibles');
      return locales;
    } catch (e) {
      print('❌ Error al obtener idiomas: $e');
      return [];
    }
  }

  /// Libera los recursos del servicio
  Future<void> dispose() async {
    try {
      print('🧹 Limpiando recursos de voz...');
      await stopListening();
      await stopSpeaking();
      _isInitialized = false;
      print('✅ Recursos liberados');
    } catch (e) {
      print('❌ Error al limpiar recursos: $e');
    }
  }
}
