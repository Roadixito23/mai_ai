import 'package:shared_preferences/shared_preferences.dart';
import '../datos/app_database.dart';
import '../modelos/task.dart';

/// Tareas guardadas en SQLite. Cada cambio queda marcado para sincronizar.
class TaskService {
  TaskService({AppDatabase? db}) : _injected = db;

  static const String _workKey = 'pomodoro_work_minutes';
  static const String _breakKey = 'pomodoro_break_minutes';

  final AppDatabase? _injected;

  // Se resuelve al usarse: TimerService.shared se crea antes de abrir la base.
  AppDatabase get _store => _injected ?? AppDatabase.instance;

  Task _fromRow(Map<String, Object?> r) => Task(
        id: r['id'] as String,
        title: r['title'] as String,
        date: parseDay(r['date'] as String),
        isCompleted: (r['is_completed'] as int) == 1,
        pomodorosCompleted: r['pomodoros_completed'] as int,
        estimatedPomodoros: r['estimated_pomodoros'] as int,
      );

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final rows = _store.db.select(
      'SELECT * FROM tasks WHERE date = ? AND deleted_at IS NULL ORDER BY rowid',
      [dayString(date)],
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> addTask(Task task) async {
    _store.db.execute(
      'INSERT INTO tasks (id, title, date, is_completed, pomodoros_completed, '
      'estimated_pomodoros, updated_at, dirty) VALUES (?, ?, ?, ?, ?, ?, ?, 1)',
      [
        task.id,
        task.title,
        dayString(task.date),
        task.isCompleted ? 1 : 0,
        task.pomodorosCompleted,
        task.estimatedPomodoros,
        AppDatabase.nowMs(),
      ],
    );
    _store.notifyLocalChange();
  }

  Future<void> updateTask(Task task) async {
    _store.db.execute(
      'UPDATE tasks SET title = ?, date = ?, is_completed = ?, pomodoros_completed = ?, '
      'estimated_pomodoros = ?, updated_at = ?, dirty = 1 '
      'WHERE id = ? AND deleted_at IS NULL',
      [
        task.title,
        dayString(task.date),
        task.isCompleted ? 1 : 0,
        task.pomodorosCompleted,
        task.estimatedPomodoros,
        AppDatabase.nowMs(),
        task.id,
      ],
    );
    _store.notifyLocalChange();
  }

  /// Borrado lógico: la fila queda para avisar a los demás dispositivos.
  Future<void> deleteTask(Task task) async {
    final now = AppDatabase.nowMs();
    _store.db.execute(
      'UPDATE tasks SET deleted_at = ?, updated_at = ?, dirty = 1 WHERE id = ?',
      [now, now, task.id],
    );
    _store.notifyLocalChange();
  }

  // La duración del pomodoro es una preferencia de este dispositivo: no se sincroniza.
  Future<({int work, int rest})> getPomodoroSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      work: prefs.getInt(_workKey) ?? 25,
      rest: prefs.getInt(_breakKey) ?? 5,
    );
  }

  Future<void> savePomodoroSettings(int workMinutes, int breakMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_workKey, workMinutes);
    await prefs.setInt(_breakKey, breakMinutes);
  }
}
