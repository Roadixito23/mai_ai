/// Cómo se traduce cada columna entre SQLite y Supabase.
enum SyncType {
  text,
  integer,
  boolean,

  /// SQLite guarda milisegundos UTC; Supabase, un timestamptz ISO-8601.
  timestamp,
}

class SyncColumn {
  final String name;
  final SyncType type;
  const SyncColumn(this.name, this.type);
}

class SyncTable {
  final String name;
  final List<SyncColumn> columns;
  const SyncTable(this.name, this.columns);

  Map<String, dynamic> toRemote(Map<String, Object?> row) {
    final out = <String, dynamic>{};
    for (final c in columns) {
      final v = row[c.name];
      out[c.name] = v == null
          ? null
          : switch (c.type) {
              SyncType.text || SyncType.integer => v,
              SyncType.boolean => v == 1,
              SyncType.timestamp => DateTime.fromMillisecondsSinceEpoch(
                  v as int,
                  isUtc: true,
                ).toIso8601String(),
            };
    }
    return out;
  }

  Map<String, Object?> fromRemote(Map<String, dynamic> remote) {
    final out = <String, Object?>{};
    for (final c in columns) {
      final v = remote[c.name];
      out[c.name] = v == null
          ? null
          : switch (c.type) {
              SyncType.text || SyncType.integer => v,
              SyncType.boolean => (v as bool) ? 1 : 0,
              SyncType.timestamp =>
                DateTime.parse(v as String).toUtc().millisecondsSinceEpoch,
            };
    }
    return out;
  }
}

const _id = SyncColumn('id', SyncType.text);
const _updatedAt = SyncColumn('updated_at', SyncType.timestamp);
const _deletedAt = SyncColumn('deleted_at', SyncType.timestamp);

const List<SyncTable> syncTables = [
  SyncTable('tasks', [
    _id,
    SyncColumn('title', SyncType.text),
    SyncColumn('date', SyncType.text),
    SyncColumn('is_completed', SyncType.boolean),
    SyncColumn('pomodoros_completed', SyncType.integer),
    SyncColumn('estimated_pomodoros', SyncType.integer),
    _updatedAt,
    _deletedAt,
  ]),
  SyncTable('timers', [
    _id,
    SyncColumn('label', SyncType.text),
    SyncColumn('kind', SyncType.text),
    SyncColumn('duration_seconds', SyncType.integer),
    SyncColumn('status', SyncType.text),
    SyncColumn('ends_at', SyncType.timestamp),
    SyncColumn('remaining_seconds', SyncType.integer),
    SyncColumn('task_id', SyncType.text),
    SyncColumn('task_date', SyncType.text),
    SyncColumn('handled', SyncType.boolean),
    _updatedAt,
    _deletedAt,
  ]),
  SyncTable('messages', [
    _id,
    SyncColumn('text', SyncType.text),
    SyncColumn('is_user', SyncType.boolean),
    SyncColumn('model_id', SyncType.text),
    SyncColumn('created_at', SyncType.timestamp),
    _updatedAt,
    _deletedAt,
  ]),
];
