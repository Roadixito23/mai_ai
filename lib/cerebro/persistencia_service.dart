import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/chat_message.dart';

class PersistenciaService {
  static const String _messagesKey = 'chat_messages';

  // Guardar mensajes
  Future<void> guardarMensajes(List<ChatMessage> mensajes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mensajesJson = mensajes.map((m) => m.toJson()).toList();
      await prefs.setString(_messagesKey, jsonEncode(mensajesJson));
    } catch (e) {
      print('Error al guardar mensajes: $e');
    }
  }

  // Cargar mensajes
  Future<List<ChatMessage>> cargarMensajes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mensajesString = prefs.getString(_messagesKey);

      if (mensajesString == null) return [];

      final List<dynamic> mensajesJson = jsonDecode(mensajesString);
      return mensajesJson
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error al cargar mensajes: $e');
      return [];
    }
  }

  // Limpiar historial
  Future<void> limpiarMensajes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_messagesKey);
    } catch (e) {
      print('Error al limpiar mensajes: $e');
    }
  }
}
