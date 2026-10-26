import '../modelos/mai_timer.dart';
import 'app_database.dart';

/// Temporizadores guardados en SQLite.
class TimerStore {
  TimerStore({AppDatabase? db}) : _injected = db;

  final AppDatabase? _injected;
  AppDatabase get _store => _injected ?? AppDatabase.instance;

  static int _ms(DateTime d) => d.toUtc().millisecondsSinceEpoch;
  static DateTime _date(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

  List<MaiTimer> loadAll() {
    final rows = _store.db.select(
      'SELECT * FROM timers WHERE deleted_at IS NULL ORDER BY updated_at',
    );
    return rows
        .map((r) => MaiTimer(
              id: r['id'] as String,
              label: r['label'] as String,
              kind: TimerKind.values.byName(r['kind'] as String),
              durationSeconds: r['duration_seconds'] as int,
              status: TimerStatus.values.byName(r['status'] as String),
              endsAt: r['ends_at'] == null ? null : _date(r['ends_at'] as int),
              remainingSeconds: r['remaining_seconds'] as int?,
              taskId: r['task_id'] as String?,
              taskDate: r['task_date'] == null ? null : parseDay(r['task_date'] as String),
              handled: (r['handled'] as int) == 1,
              updatedAt: _date(r['updated_at'] as int),
            ))
        .toList();
  }

  /// Guarda el temporizador solo si cambió, para no volver a sincronizar lo mismo.
  void upsert(MaiTimer t) {
    final existing = _store.db.select(
      'SELECT updated_at, deleted_at FROM timers WHERE id = ?',
      [t.id],
    );
    if (existing.isNotEmpty &&
        existing.first['deleted_at'] == null &&
        existing.first['updated_at'] == _ms(t.updatedAt)) {
      return;
    }

    _store.db.execute(
      'INSERT INTO timers (id, label, kind, duration_seconds, status, ends_at, '
      'remaining_seconds, task_id, task_date, handled, updated_at, deleted_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 1) '
      'ON CONFLICT(id) DO UPDATE SET label = excluded.label, kind = excluded.kind, '
      'duration_seconds = excluded.duration_seconds, status = excluded.status, '
      'ends_at = excluded.ends_at, remaining_seconds = excluded.remaining_seconds, '
      'task_id = excluded.task_id, task_date = excluded.task_date, '
      'handled = excluded.handled, updated_at = excluded.updated_at, '
      'deleted_at = NULL, dirty = 1',
      [
        t.id,
        t.label,
        t.kind.name,
        t.durationSeconds,
        t.status.name,
        t.endsAt == null ? null : _ms(t.endsAt!),
        t.remainingSeconds,
        t.taskId,
        t.taskDate == null ? null : dayString(t.taskDate!),
        t.handled ? 1 : 0,
        _ms(t.updatedAt),
      ],
    );
    _store.notifyLocalChange();
  }

  void softDelete(String id) {
    final now = AppDatabase.nowMs();
    _store.db.execute(
      'UPDATE timers SET deleted_at = ?, updated_at = ?, dirty = 1 '
      'WHERE id = ? AND deleted_at IS NULL',
      [now, now, id],
    );
    _store.notifyLocalChange();
  }
}
