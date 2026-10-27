import 'package:flutter/foundation.dart';
import '../modelos/chat_message.dart';
import 'ai_exceptions.dart';
import 'ai_service.dart';
import 'config.dart';
import 'herramientas.dart';
import 'persistencia_service.dart';
import 'tts_service.dart';

/// Lógica del chat: historial, envío con streaming, errores y modo voz.
/// La pantalla solo se encarga de dibujar este estado.
class ChatController extends ChangeNotifier {
  ChatController({
    ChatBackend? backend,
    PersistenciaService? storage,
    TTSService? tts,
  })  : _backend = backend ?? AIService(herramientas: Herramientas()),
        _storage = storage ?? PersistenciaService(),
        _tts = tts;

  final ChatBackend _backend;
  final PersistenciaService _storage;
  final TTSService? _tts;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _isVoiceMode = false;
  String? _modelName;
  AIException? _lastError;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isVoiceMode => _isVoiceMode;
  String? get modelName => _modelName;

  /// Último error del modelo; la pantalla lo usa para ofrecer configurar la key.
  AIException? get lastError => _lastError;

  Future<void> init() async {
    final loaded = await _storage.cargarMensajes();
    _messages
      ..clear()
      ..addAll(loaded);
    _isLoadingHistory = false;
    notifyListeners();
    await refreshModelName();
  }

  /// Vuelve a leer el historial (llegaron mensajes de otro dispositivo).
  Future<void> reloadFromStorage() async {
    if (_isLoading) return; // no pisar una respuesta en curso
    final loaded = await _storage.cargarMensajes();
    _messages
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Future<void> refreshModelName() async {
    _modelName = await Config.getCurrentModelName();
    notifyListeners();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _lastError = null;
    _isLoading = true;
    _messages.add(ChatMessage.user(text: trimmed));
    notifyListeners();
    await _save();

    // Placeholder que se va llenando con el streaming.
    var reply = ChatMessage.assistant(text: '');
    _messages.add(reply);
    notifyListeners();

    final buffer = StringBuffer();
    final acciones = <String>[];
    try {
      final history = _messages
          .sublist(0, _messages.length - 1)
          .where((m) => !m.isError)
          .toList();
      final stream = _backend.sendMessageStream(history, onAction: (resumen) {
        acciones.add(resumen);
        reply = reply.copyWith(metadata: {'acciones': List.of(acciones)});
        _replaceLast(reply);
      });
      await for (final chunk in stream) {
        buffer.write(chunk);
        reply = reply.copyWith(text: buffer.toString());
        _replaceLast(reply);
      }
      if (buffer.isEmpty) {
        throw const AIException(AIErrorKind.unknown, 'respuesta vacía');
      }
      if (_isVoiceMode) await _tts?.speak(buffer.toString());
    } on AIException catch (e) {
      _lastError = e;
      _replaceLast(ChatMessage.error(errorMessage: e.userMessage));
    } catch (e) {
      debugPrint('Error en el chat: $e');
      _replaceLast(ChatMessage.error(
        errorMessage: const AIException(AIErrorKind.unknown).userMessage,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await _save();
  }

  Future<void> clear() async {
    _messages.clear();
    notifyListeners();
    await _storage.limpiarMensajes();
  }

  void toggleVoiceMode() {
    _isVoiceMode = !_isVoiceMode;
    if (!_isVoiceMode) _tts?.stop();
    notifyListeners();
  }

  void _replaceLast(ChatMessage message) {
    _messages[_messages.length - 1] = message;
    notifyListeners();
  }

  /// Los errores son transitorios: no se guardan en disco ni viajan como contexto.
  Future<void> _save() =>
      _storage.guardarMensajes(_messages.where((m) => !m.isError).toList());
}
