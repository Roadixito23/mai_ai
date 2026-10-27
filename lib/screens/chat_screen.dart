import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cerebro/ai_exceptions.dart';
import '../cerebro/ai_service.dart';
import '../cerebro/api_key_store.dart';
import '../cerebro/chat_controller.dart';
import '../cerebro/config.dart';
import '../cerebro/tts_service.dart';
import '../cerebro/voice_recorder.dart';
import '../datos/auth_service.dart';
import '../datos/sync_service.dart';
import '../modelos/ai_model.dart';
import '../providers/theme_provider.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/empty_chat_view.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_selector_dialog.dart';
import '../widgets/text_composer.dart';
import '../widgets/theme_selector_dialog.dart';
import '../widgets/typing_indicator.dart';
import 'mai_pet_screen.dart';
import 'memorias_screen.dart';
import 'tasks_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiKeyStore _keyStore = ApiKeyStore();
  final TTSService _ttsService = TTSService();
  final VoiceRecorder _recorder = VoiceRecorder();
  bool _isRecording = false;
  late final ChatController _chat;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Set<String>>? _syncSub;

  @override
  void initState() {
    super.initState();
    _chat = ChatController(tts: _ttsService);
    _syncSub = SyncService.shared.remoteChanges.listen((tables) {
      if (tables.contains('messages')) _chat.reloadFromStorage().then((_) => _scrollToBottom());
    });
    _chat.init().then((_) {
      _scrollToBottom();
      _askForApiKeyIfMissing();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _chat.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _ttsService.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _askForApiKeyIfMissing() async {
    // Con Supabase no hace falta key local: la usa el proxy.
    if (!mounted || AuthService.configured || await _keyStore.hasKey()) return;
    await _mostrarDialogoApiKey();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Mai dejará de sincronizar y de responder en este dispositivo hasta que vuelvas '
          'a iniciar sesión. Lo guardado aquí no se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) await AuthService.shared.signOut();
  }

  Future<void> _mostrarDialogoApiKey() async {
    if (!mounted) return;
    await ApiKeyDialog.show(context, _keyStore);
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    _scrollToBottom();

    await _chat.send(text);
    _scrollToBottom();

    final error = _chat.lastError;
    if (error != null && error.needsApiKey && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.userMessage),
          action: SnackBarAction(
            label: 'Configurar',
            onPressed: _mostrarDialogoApiKey,
          ),
        ),
      );
    }
  }

  /// Primer toque: graba. Segundo toque: transcribe y envía.
  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      _ttsService.stop(); // que Mai no se escuche a sí misma
      if (!await _recorder.start()) {
        _avisar('Mai necesita permiso para usar el micrófono.');
        return;
      }
      setState(() => _isRecording = true);
      return;
    }

    setState(() => _isRecording = false);
    final path = await _recorder.stop();
    if (path == null) return;
    _scrollToBottom();
    final understood = await _chat.sendVoice(path);
    VoiceRecorder.deleteFile(path);
    _scrollToBottom();
    if (!understood) _avisar('No te escuché bien. Intenta de nuevo.');
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
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
            child: const Text('Limpiar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) await _chat.clear();
  }

  Future<void> _mostrarSelectorModelo() async {
    final currentModel = await Config.getSavedModel();
    var models = AIModel.availableModels;
    try {
      final fetched = await AIService(keyStore: _keyStore).listModels();
      if (fetched.isNotEmpty) models = fetched;
    } on AIException catch (e) {
      debugPrint('No se pudo cargar la lista de modelos: $e');
    }
    if (!mounted) return;

    final selectedModel = await showDialog<AIModel>(
      context: context,
      builder: (context) => ModelSelectorDialog(currentModel: currentModel, models: models),
    );

    if (selectedModel != null) {
      await Config.saveModel(selectedModel.id);
      await _chat.refreshModelName();

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
    _chat.toggleVoiceMode();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _chat.isVoiceMode
              ? 'Modo Voz activado - Las respuestas se reproducirán como audio'
              : 'Modo Chat activado - Las respuestas se mostrarán como texto',
        ),
        backgroundColor: _chat.isVoiceMode ? Colors.deepPurple : Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _abrir(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final messages = _chat.messages;
        final themeMode = Provider.of<ThemeProvider>(context).themeMode;

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
                    _chat.isVoiceMode ? Icons.volume_up : Icons.chat_bubble_outline,
                    color: _chat.isVoiceMode ? Colors.deepPurple : null,
                  ),
                  title: Text(_chat.isVoiceMode ? 'Modo Voz' : 'Modo Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleVoiceMode();
                  },
                ),
                ListTile(
                  leading: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : themeMode == ThemeMode.light
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
                  subtitle: _chat.modelName != null ? Text(_chat.modelName!) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarSelectorModelo();
                  },
                ),
                // Con Supabase la key de Groq vive en el servidor.
                if (!AuthService.configured)
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: const Text('API key de Groq'),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarDialogoApiKey();
                    },
                  ),
                const _SyncTile(),
                ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: const Text('Tareas'),
                  onTap: () => _abrir(const TasksScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined),
                  title: const Text('Lo que Mai recuerda'),
                  onTap: () => _abrir(const MemoriasScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.face_retouching_natural),
                  title: const Text('mai~'),
                  onTap: () => _abrir(const MaiPetScreen()),
                ),
                if (AuthService.shared.isSignedIn)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    subtitle: Text(AuthService.shared.email ?? 'En este dispositivo'),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmarCerrarSesion();
                    },
                  ),
                if (messages.isNotEmpty) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      'Limpiar conversación',
                      style: TextStyle(color: Colors.red),
                    ),
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
                if (_chat.modelName != null)
                  Text(
                    _chat.modelName!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                  ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: _chat.isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: messages.isEmpty
                          ? const EmptyChatView()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(8.0),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final isStreaming =
                                    _chat.isLoading && index == messages.length - 1;
                                return MessageBubble(
                                  message: messages[index],
                                  isAnimating: isStreaming,
                                );
                              },
                            ),
                    ),
                    if (_chat.isLoading) const TypingIndicator(),
                    const Divider(height: 1),
                    TextComposer(
                      controller: _textController,
                      onSubmit: _handleSubmit,
                      isLoading: _chat.isLoading,
                      isRecording: _isRecording,
                      onMicPressed: _toggleRecording,
                    ),
                  ],
                ),
        );
      },
    );
  }
}


/// Estado de la sincronización con Supabase; al tocarlo fuerza una sincronización.
class _SyncTile extends StatelessWidget {
  const _SyncTile();

  String _subtitle(SyncService sync) {
    switch (sync.status) {
      case SyncStatus.disabled:
        return AuthService.configured
            ? 'Inicia sesión para sincronizar'
            : 'Sin configurar (falta env.json)';
      case SyncStatus.syncing:
        return 'Sincronizando…';
      case SyncStatus.failed:
        return 'Sin conexión: los cambios quedan pendientes';
      case SyncStatus.idle:
        final at = sync.lastSyncAt;
        if (at == null) return 'Al día';
        final h = at.hour.toString().padLeft(2, '0');
        final m = at.minute.toString().padLeft(2, '0');
        return 'Al día · $h:$m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.shared;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => ListTile(
        leading: Icon(
          sync.status == SyncStatus.failed ? Icons.cloud_off : Icons.cloud_sync_outlined,
        ),
        title: const Text('Sincronización'),
        subtitle: Text(_subtitle(sync)),
        onTap: sync.status == SyncStatus.syncing ? null : sync.sync,
      ),
    );
  }
}
