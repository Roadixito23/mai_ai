import '../datos/app_database.dart';
import '../modelos/chat_message.dart';

/// Historial del chat guardado en SQLite.
class PersistenciaService {
  PersistenciaService({AppDatabase? db}) : _injected = db;

  final AppDatabase? _injected;
  AppDatabase get _store => _injected ?? AppDatabase.instance;

  /// Guarda lo nuevo o modificado; los mensajes que no cambiaron no se tocan.
  Future<void> guardarMensajes(List<ChatMessage> mensajes) async {
    final db = _store.db;
    final existentes = {
      for (final r in db.select('SELECT id, text FROM messages WHERE deleted_at IS NULL'))
        r['id'] as String: r['text'] as String,
    };

    var cambios = false;
    _store.transaction(() {
      for (final m in mensajes) {
        if (m.text.isEmpty || existentes[m.id] == m.text) continue;
        final now = AppDatabase.nowMs();
        db.execute(
          'INSERT INTO messages (id, text, is_user, model_id, created_at, updated_at, deleted_at, dirty) '
          'VALUES (?, ?, ?, ?, ?, ?, NULL, 1) '
          'ON CONFLICT(id) DO UPDATE SET text = excluded.text, model_id = excluded.model_id, '
          'updated_at = excluded.updated_at, deleted_at = NULL, dirty = 1',
          [
            m.id,
            m.text,
            m.isUser ? 1 : 0,
            m.modelId,
            m.timestamp.toUtc().millisecondsSinceEpoch,
            now,
          ],
        );
        cambios = true;
      }
    });
    if (cambios) _store.notifyLocalChange();
  }

  Future<List<ChatMessage>> cargarMensajes() async {
    final rows = _store.db.select(
      'SELECT * FROM messages WHERE deleted_at IS NULL ORDER BY created_at, rowid',
    );
    return rows
        .map((r) => ChatMessage(
              id: r['id'] as String,
              text: r['text'] as String,
              isUser: (r['is_user'] as int) == 1,
              modelId: r['model_id'] as String?,
              timestamp: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int, isUtc: true)
                  .toLocal(),
            ))
        .toList();
  }

  Future<void> limpiarMensajes() async {
    final now = AppDatabase.nowMs();
    _store.db.execute(
      'UPDATE messages SET deleted_at = ?, updated_at = ?, dirty = 1 WHERE deleted_at IS NULL',
      [now, now],
    );
    _store.notifyLocalChange();
  }
}
