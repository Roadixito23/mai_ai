import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cerebro/ai_service.dart';
import '../cerebro/persistencia_service.dart';
import '../cerebro/voice_service.dart';
import '../modelos/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/text_composer.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final AIService _aiService = AIService();
  final PersistenciaService _persistenciaService = PersistenciaService();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _voiceMode = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _voiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _inicializarVoz();
  }

  Future<void> _cargarHistorial() async {
    final mensajes = await _persistenciaService.cargarMensajes();
    setState(() {
      _messages.addAll(mensajes);
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  Future<void> _guardarHistorial() async {
    await _persistenciaService.guardarMensajes(_messages);
  }

  /// Inicializa el servicio de voz y configura los callbacks
  Future<void> _inicializarVoz() async {
    print('🎤 Inicializando servicio de voz...');

    // Configurar callbacks del servicio de voz
    _voiceService.onTextRecognized = (text) {
      print('✅ Texto reconocido en UI: $text');
      if (_voiceMode && text.isNotEmpty) {
        _handleSubmit(text);
      }
    };

    _voiceService.onListeningStateChanged = (isListening) {
      print('📊 Estado de escucha cambió: $isListening');
      setState(() {
        _isListening = isListening;
      });
    };

    _voiceService.onSpeakingStateChanged = (isSpeaking) {
      print('📊 Estado de habla cambió: $isSpeaking');
      setState(() {
        _isSpeaking = isSpeaking;
      });

      // Cuando Mai termina de hablar, volver a escuchar si está en modo voz
      if (!isSpeaking && _voiceMode) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_voiceMode && !_isListening) {
            _startListening();
          }
        });
      }
    };

    _voiceService.onError = (error) {
      print('❌ Error de voz en UI: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    // Intentar inicializar el servicio
    bool initialized = await _voiceService.initialize();
    setState(() {
      _voiceInitialized = initialized;
    });

    if (initialized) {
      print('✅ Servicio de voz inicializado correctamente');
    } else {
      print('❌ No se pudo inicializar el servicio de voz');
    }
  }

  /// Activa o desactiva el modo de voz
  Future<void> _toggleVoiceMode() async {
    if (!_voiceInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El servicio de voz no está disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _voiceMode = !_voiceMode;
    });

    if (_voiceMode) {
      // Modo voz activado
      print('🎤 Modo voz activado');
      await _voiceService.speak('Modo de voz activado. Dime qué necesitas.');

      // Esperar a que termine de hablar y luego empezar a escuchar
      Future.delayed(const Duration(seconds: 3), () {
        if (_voiceMode && !_isListening) {
          _startListening();
        }
      });
    } else {
      // Modo voz desactivado
      print('🛑 Modo voz desactivado');
      await _voiceService.stopListening();
      await _voiceService.stopSpeaking();
    }
  }

  /// Inicia la escucha de voz
  Future<void> _startListening() async {
    if (!_voiceInitialized || !_voiceMode) return;

    print('🎤 Iniciando escucha...');
    await _voiceService.startListening();
  }

  /// Detiene la escucha de voz
  Future<void> _stopListening() async {
    print('🛑 Deteniendo escucha...');
    await _voiceService.stopListening();
  }

  /// Alterna entre iniciar y detener la escucha
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  void _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();

    // Agregar mensaje del usuario
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();
    await _guardarHistorial();

    // Preparar mensajes para la API
    List<Map<String, String>> apiMessages = _messages.map((msg) {
      return {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      };
    }).toList();

    // Obtener respuesta de la IA
    String response = await _aiService.sendMessage(apiMessages);

    // Agregar respuesta de la IA
    setState(() {
      _messages.add(ChatMessage(text: response, isUser: false));
      _isLoading = false;
    });

    _scrollToBottom();
    await _guardarHistorial();

    // Si está en modo voz, Mai responde con voz
    if (_voiceMode && _voiceInitialized) {
      print('🗣️ Mai va a responder con voz');
      await _voiceService.speak(response);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _mostrarDialogoLimpiar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar conversación'),
        content: const Text('¿Estás seguro de que quieres borrar todo el historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Limpiar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        _messages.clear();
      });
      await _persistenciaService.limpiarMensajes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        // Atajo Ctrl+M para activar/desactivar modo voz
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyM &&
            HardwareKeyboard.instance.isControlPressed) {
          _toggleVoiceMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.purple[100],
                radius: 16,
                child: const Text(
                  'M',
                  style: TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Mai'),
              if (_voiceMode) ...[
                const SizedBox(width: 8),
                const Icon(Icons.mic, size: 16, color: Colors.purple),
              ],
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            // Botón de modo voz
            if (_voiceInitialized)
              IconButton(
                icon: Icon(
                  _voiceMode ? Icons.mic : Icons.mic_none,
                  color: _voiceMode ? Colors.purple : null,
                ),
                onPressed: _toggleVoiceMode,
                tooltip: _voiceMode ? 'Desactivar modo voz (Ctrl+M)' : 'Activar modo voz (Ctrl+M)',
              ),
            if (_messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _mostrarDialogoLimpiar,
                tooltip: 'Limpiar conversación',
              ),
          ],
        ),
        body: _isLoadingHistory
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Banner de modo voz/escucha
                  if (_voiceMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: _isListening
                          ? Colors.purple.withOpacity(0.2)
                          : _isSpeaking
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isListening
                                ? Icons.mic
                                : _isSpeaking
                                    ? Icons.volume_up
                                    : Icons.mic_none,
                            size: 20,
                            color: _isListening
                                ? Colors.purple
                                : _isSpeaking
                                    ? Colors.blue
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isListening
                                ? 'Escuchando...'
                                : _isSpeaking
                                    ? 'Mai está hablando...'
                                    : 'Modo voz activo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isListening
                                  ? Colors.purple
                                  : _isSpeaking
                                      ? Colors.blue
                                      : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _messages.isEmpty
                        ? const EmptyChatView()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return MessageBubble(message: message);
                            },
                          ),
                  ),
                  if (_isLoading) const TypingIndicator(),
                  const Divider(height: 1),
                  // Controles de voz cuando está en modo voz
                  if (_voiceMode)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.purple.withOpacity(0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botón de presionar para hablar
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _toggleListening,
                            icon: Icon(_isListening ? Icons.stop : Icons.mic),
                            label: Text(_isListening ? 'Detener' : 'Presiona para hablar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isListening ? Colors.red : Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Botón para detener voz de Mai
                          if (_isSpeaking)
                            ElevatedButton.icon(
                              onPressed: () => _voiceService.stopSpeaking(),
                              icon: const Icon(Icons.stop),
                              label: const Text('Detener voz'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Compositor de texto normal
                  if (!_voiceMode)
                    TextComposer(
                      controller: _textController,
                      onSubmit: _handleSubmit,
                      isLoading: _isLoading,
                    ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
