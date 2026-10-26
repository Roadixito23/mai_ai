import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

/// Pasa lo que la app guardaba en SharedPreferences (chat, tareas, timers) a
/// SQLite. Los IDs antiguos eran milisegundos; se reemplazan por UUID. Corre una
/// sola vez y deja todo marcado para subirse en la primera sincronización.
class LegacyMigration {
  static const String _doneKey = 'legacy_prefs_imported';
  static const String _taskPrefix = 'tasks_';
  static const String _chatKey = 'chat_messages';
  static const String _timersKey = 'mai_timers';

  static Future<void> run(AppDatabase store) async {
    if (store.getState(_doneKey) == '1') return;

    final prefs = await SharedPreferences.getInstance();
    const uuid = Uuid();
    final taskIds = <String, String>{}; // id antiguo -> UUID nuevo
    final now = AppDatabase.nowMs();

    try {
      store.transaction(() {
        final db = store.db;

        for (final key in prefs.getKeys().where((k) => k.startsWith(_taskPrefix))) {
          final day = key.substring(_taskPrefix.length);
          final list = jsonDecode(prefs.getString(key)!) as List;
          for (final j in list.cast<Map<String, dynamic>>()) {
            final newId = taskIds.putIfAbsent(j['id'] as String, uuid.v4);
            db.execute(
              'INSERT OR IGNORE INTO tasks (id, title, date, is_completed, pomodoros_completed, '
              'estimated_pomodoros, updated_at, dirty) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
              [
                newId,
                j['title'],
                day,
                (j['isCompleted'] as bool? ?? false) ? 1 : 0,
                j['pomodorosCompleted'] as int? ?? 0,
                j['estimatedPomodoros'] as int? ?? 1,
                now,
              ],
            );
          }
        }

        final chat = prefs.getString(_chatKey);
        if (chat != null) {
          for (final j in (jsonDecode(chat) as List).cast<Map<String, dynamic>>()) {
            if (j['isError'] == true) continue;
            final created = DateTime.parse(j['timestamp'] as String).toUtc().millisecondsSinceEpoch;
            db.execute(
              'INSERT OR IGNORE INTO messages (id, text, is_user, model_id, created_at, updated_at, dirty) '
              'VALUES (?, ?, ?, ?, ?, ?, 1)',
              [uuid.v4(), j['text'], (j['isUser'] as bool) ? 1 : 0, j['modelId'], created, now],
            );
          }
        }

        final timers = prefs.getString(_timersKey);
        if (timers != null) {
          for (final j in (jsonDecode(timers) as List).cast<Map<String, dynamic>>()) {
            final oldTaskId = j['taskId'] as String?;
            db.execute(
              'INSERT OR IGNORE INTO timers (id, label, kind, duration_seconds, status, ends_at, '
              'remaining_seconds, task_id, task_date, handled, updated_at, dirty) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
              [
                j['id'],
                j['label'],
                j['kind'],
                j['durationSeconds'],
                j['status'],
                j['endsAt'] == null
                    ? null
                    : DateTime.parse(j['endsAt'] as String).toUtc().millisecondsSinceEpoch,
                j['remainingSeconds'],
                oldTaskId == null ? null : taskIds[oldTaskId],
                j['taskDate'] == null ? null : (j['taskDate'] as String).substring(0, 10),
                (j['handled'] as bool? ?? false) ? 1 : 0,
                now,
              ],
            );
          }
        }

        store.setState(_doneKey, '1');
      });
    } catch (e) {
      // Sin marcar como hecho: se reintenta en el próximo arranque y no se borra nada.
      debugPrint('No se pudieron importar los datos antiguos: $e');
      return;
    }

    for (final key in prefs.getKeys().where((k) => k.startsWith(_taskPrefix)).toList()) {
      await prefs.remove(key);
    }
    await prefs.remove(_chatKey);
    await prefs.remove(_timersKey);
    store.notifyLocalChange();
  }
}
