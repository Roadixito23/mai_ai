import 'package:flutter/material.dart';
import '../cerebro/ai_service.dart';
import '../cerebro/persistencia_service.dart';
import '../cerebro/config.dart';
import '../modelos/chat_message.dart';
import '../modelos/ai_model.dart';
import '../widgets/message_bubble.dart';
import '../widgets/text_composer.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/model_selector_dialog.dart';

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
  bool _isLoading = false;
  bool _isLoadingHistory = true;
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

    // Obtener respuesta de la IA
    String response = await _aiService.sendMessage(apiMessages);

    // Agregar respuesta de la IA
    setState(() {
      _messages.add(ChatMessage(text: response, isUser: false));
      _isLoading = false;
    });

    _scrollToBottom();
    await _guardarHistorial();
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
            content: Text('✅ Modelo cambiado a: ${selectedModel.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
              ],
            ),
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
        actions: [
          // Botón de selector de modelo
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _mostrarSelectorModelo,
            tooltip: 'Cambiar modelo de IA',
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
    super.dispose();
  }
}
