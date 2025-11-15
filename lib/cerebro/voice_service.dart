import 'package:speech_to_text/speech_to_text.dart';
import 'package:text_to_speech/text_to_speech.dart';

class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  final TextToSpeech _tts = TextToSpeech();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  // Callbacks
  Function(String)? onTextRecognized;
  Function(bool)? onListeningStateChanged;
  Function(bool)? onSpeakingStateChanged;  // ← AGREGADO
  Function(String)? onError;

  /// Inicializar servicios de voz
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🎤 Inicializando servicios de voz...');

      // Inicializar Speech-to-Text
      final sttAvailable = await _speechToText.initialize(
        onStatus: (status) {
          print('📊 Estado STT: $status');
          _isListening = status == 'listening';
          onListeningStateChanged?.call(_isListening);
        },
        onError: (error) {
          print('❌ Error STT: ${error.errorMsg}');
          _isListening = false;
          onListeningStateChanged?.call(false);
          onError?.call('Error de reconocimiento: ${error.errorMsg}');
        },
      );

      if (!sttAvailable) {
        final errorMsg = 'Reconocimiento de voz no disponible.\n'
            'Habilítalo en: Configuración > Privacidad > Voz';
        print('❌ $errorMsg');
        onError?.call(errorMsg);
        return false;
      }

      // Verificar idiomas disponibles
      final locales = await _speechToText.locales();
      print('🌍 Idiomas disponibles: ${locales.length}');

      final spanishLocale = locales.firstWhere(
            (locale) => locale.localeId.startsWith('es'),
        orElse: () => locales.first,
      );
      print('🇪🇸 Usando: ${spanishLocale.name}');

      // Configurar TTS
      await _configureTTS();

      _isInitialized = true;
      print('✅ Servicios de voz listos');
      return true;

    } catch (e) {
      print('❌ Error inicializando: $e');
      onError?.call('Error al inicializar servicios de voz');
      return false;
    }
  }

  /// Configurar Text-to-Speech
  Future<void> _configureTTS() async {
    try {
      // Configurar español
      await _tts.setLanguage('es-ES');
      await _tts.setRate(0.5);  // Velocidad normal
      await _tts.setVolume(1.0); // Volumen máximo

      print('🔊 TTS configurado para español');
    } catch (e) {
      print('⚠️ Error configurando TTS: $e');
      // No es crítico, continuar
    }
  }

  /// Iniciar escucha de voz
  Future<void> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('No se pudo inicializar');
        return;
      }
    }

    if (_isListening) {
      print('⚠️ Ya está escuchando');
      return;
    }

    // Si está hablando, esperar
    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      print('🎤 Iniciando escucha...');

      await _speechToText.listen(
        onResult: (result) {
          print('📝 Parcial: ${result.recognizedWords}');

          if (result.finalResult) {
            final text = result.recognizedWords.trim();
            print('✅ Final: "$text"');

            if (text.isNotEmpty) {
              onTextRecognized?.call(text);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: 'es-ES',
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
      onListeningStateChanged?.call(true);
      print('✅ Escuchando...');

    } catch (e) {
      print('❌ Error al escuchar: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
      onError?.call('Error al iniciar escucha');
    }
  }

  /// Detener escucha
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      onListeningStateChanged?.call(false);
      print('🛑 Escucha detenida');
    } catch (e) {
      print('❌ Error al detener: $e');
    }
  }

  /// Hablar texto
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    try {
      print('🔊 Mai dice: "$text"');

      // Notificar que empieza a hablar
      _isSpeaking = true;
      onSpeakingStateChanged?.call(true);

      // Hablar el texto
      await _tts.speak(text);

      // Calcular tiempo aproximado
      final words = text.split(' ').length;
      final seconds = (words * 0.4).ceil() + 1;

      print('⏱️ Esperando ~$seconds segundos...');
      await Future.delayed(Duration(seconds: seconds));

      // Notificar que terminó de hablar
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      print('✅ Terminó de hablar');

    } catch (e) {
      print('❌ Error al hablar: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    }
  }

  /// Detener reproducción de voz
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
      print('🛑 Voz detenida');
    } catch (e) {
      print('❌ Error al detener voz: $e');
    }
  }

  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  /// Limpiar recursos
  Future<void> dispose() async {
    await stopListening();
    await stopSpeaking();
    _isInitialized = false;
    _isListening = false;
    _isSpeaking = false;
    print('🧹 Servicios de voz limpiados');
  }
}