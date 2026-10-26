import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Base de datos local (SQLite). Es la fuente de verdad: la app funciona igual
/// sin conexión y [SyncService] la espeja con Supabase cuando hay red.
///
/// Las tablas sincronizadas comparten estas columnas:
/// - `updated_at`: milisegundos UTC de la última edición (gana la más reciente).
/// - `deleted_at`: borrado lógico, para que otros dispositivos se enteren.
/// - `dirty`: 1 si tiene cambios que aún no se enviaron.
class AppDatabase {
  AppDatabase._(this.db) {
    _migrate();
  }

  static const int _schemaVersion = 1;

  static AppDatabase? _instance;

  static AppDatabase get instance =>
      _instance ?? (throw StateError('Falta llamar a AppDatabase.initialize()'));

  static Future<AppDatabase> initialize() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationSupportDirectory();
    final database = sqlite3.open(p.join(dir.path, 'mai.db'));
    database.execute('PRAGMA journal_mode = WAL');
    return _instance = AppDatabase._(database);
  }

  /// Base en memoria, para tests.
  factory AppDatabase.memory() => AppDatabase._(sqlite3.openInMemory());

  final Database db;

  final _localChanges = StreamController<void>.broadcast();

  /// Se emite tras cada escritura local; la sincronización lo usa para empujar.
  Stream<void> get localChanges => _localChanges.stream;

  void notifyLocalChange() {
    if (!_localChanges.isClosed) _localChanges.add(null);
  }

  static int nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Varias escrituras como una sola operación: o se aplican todas o ninguna.
  T transaction<T>(T Function() body) {
    db.execute('BEGIN');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  String? getState(String key) {
    final rows = db.select('SELECT value FROM sync_state WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setState(String key, String value) {
    db.execute(
      'INSERT INTO sync_state (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  void _migrate() {
    final current = db.userVersion;
    if (current >= _schemaVersion) return;

    transaction(() {
      if (current < 1) {
        db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            pomodoros_completed INTEGER NOT NULL DEFAULT 0,
            estimated_pomodoros INTEGER NOT NULL DEFAULT 1,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');
        db.execute('CREATE INDEX tasks_date_idx ON tasks (date)');

        db.execute('''
          CREATE TABLE timers (
            id TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            kind TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            status TEXT NOT NULL,
            ends_at INTEGER,
            remaining_seconds INTEGER,
            task_id TEXT,
            task_date TEXT,
            handled INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');

        db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            model_id TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            dirty INTEGER NOT NULL DEFAULT 1
          )''');
        db.execute('CREATE INDEX messages_created_idx ON messages (created_at)');

        db.execute('''
          CREATE TABLE sync_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      }
    });
    db.userVersion = _schemaVersion;
  }

  void dispose() {
    _localChanges.close();
    db.close();
  }
}

/// `YYYY-MM-DD` de una fecha (sin hora), como se guardan los días en SQLite y Supabase.
String dayString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String s) {
  final parts = s.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

@visibleForTesting
void resetAppDatabaseForTests() => AppDatabase._instance = null;
