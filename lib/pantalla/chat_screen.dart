import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cerebro/ai_service.dart';
import '../cerebro/persistencia_service.dart';
import '../cerebro/tts_service.dart';
import '../cerebro/config.dart';
import '../modelos/chat_message.dart';
import '../modelos/ai_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/text_composer.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/model_selector_dialog.dart';
import '../widgets/theme_selector_dialog.dart';
import '../screens/mai_pet_screen.dart';
import '../screens/tasks_screen.dart';

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
  final TTSService _ttsService = TTSService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _isVoiceMode = false;
  String? _currentModelName;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _cargarModeloActual();
  }

  Future<void> _cargarModeloActual() async {
    final modelName = await Config.getCurrentModelName();
    setState(() {
      _currentModelName = modelName;
    });
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

    // Crear un mensaje vacío para la respuesta de la IA
    final aiMessageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(text: '', isUser: false));
    });

    // Obtener respuesta de la IA con streaming
    final responseBuffer = StringBuffer();
    try {
      await for (final chunk in _aiService.sendMessageStream(apiMessages)) {
        responseBuffer.write(chunk);
        setState(() {
          _messages[aiMessageIndex] = ChatMessage(
            text: responseBuffer.toString(),
            isUser: false,
          );
        });
        _scrollToBottom();
      }

      // Si está en modo voz, convertir la respuesta a audio
      if (_isVoiceMode && responseBuffer.isNotEmpty) {
        await _ttsService.speak(responseBuffer.toString());
      }
    } catch (e) {
      print('Error en streaming: $e');
      setState(() {
        _messages[aiMessageIndex] = ChatMessage(
          text: 'Error al recibir respuesta. Intenta de nuevo.',
          isUser: false,
        );
      });
    }

    setState(() {
      _isLoading = false;
    });

    _scrollToBottom();
    await _guardarHistorial();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _mostrarSelectorModelo() async {
    final currentModel = await Config.getSavedModel();

    final selectedModel = await showDialog<AIModel>(
      context: context,
      builder: (context) => ModelSelectorDialog(
        currentModel: currentModel,
      ),
    );

    if (selectedModel != null) {
      await Config.saveModel(selectedModel.id);
      await _cargarModeloActual();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modelo cambiado a: ${selectedModel.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _mostrarSelectorTema() async {
    await showDialog(
      context: context,
      builder: (context) => const ThemeSelectorDialog(),
    );
  }

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });

    // Detener cualquier reproducción de audio al cambiar de modo
    if (!_isVoiceMode) {
      _ttsService.stop();
    }

    // Mostrar notificación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVoiceMode
              ? 'Modo Voz activado - Las respuestas se reproducirán como audio'
              : 'Modo Chat activado - Las respuestas se mostrarán como texto',
        ),
        backgroundColor: _isVoiceMode ? Colors.deepPurple : Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    radius: 28,
                    child: const Text(
                      'M',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mai',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                _isVoiceMode ? Icons.volume_up : Icons.chat_bubble_outline,
                color: _isVoiceMode ? Colors.deepPurple : null,
              ),
              title: Text(_isVoiceMode ? 'Modo Voz' : 'Modo Chat'),
              onTap: () {
                Navigator.pop(context);
                _toggleVoiceMode();
              },
            ),
            ListTile(
              leading: Icon(
                Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Provider.of<ThemeProvider>(context).themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.settings_suggest,
              ),
              title: const Text('Tema'),
              onTap: () {
                Navigator.pop(context);
                _mostrarSelectorTema();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Modelo de IA'),
              subtitle: _currentModelName != null ? Text(_currentModelName!) : null,
              onTap: () {
                Navigator.pop(context);
                _mostrarSelectorModelo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('Tareas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TasksScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('mai~'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaiPetScreen()),
                );
              },
            ),
            if (_messages.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Limpiar conversación', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDialogoLimpiar();
                },
              ),
            ],
          ],
        ),
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mai'),
            if (_currentModelName != null)
              Text(
                _currentModelName!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const EmptyChatView()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return MessageBubble(
                              message: message,
                              isAnimating: false,
                            );
                          },
                        ),
                ),
                if (_isLoading) const TypingIndicator(),
                const Divider(height: 1),
                TextComposer(
                  controller: _textController,
                  onSubmit: _handleSubmit,
                  isLoading: _isLoading,
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
