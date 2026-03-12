import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/task.dart';

class TaskService {
  static const String _prefix = 'tasks_';
  static const String _workKey = 'pomodoro_work_minutes';
  static const String _breakKey = 'pomodoro_break_minutes';

  String _dayKey(DateTime date) =>
      '$_prefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dayKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> _saveTasksForDate(DateTime date, List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dayKey(date),
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> addTask(Task task) async {
    final tasks = await getTasksForDate(task.date);
    tasks.add(task);
    await _saveTasksForDate(task.date, tasks);
  }

  Future<void> updateTask(Task task) async {
    final tasks = await getTasksForDate(task.date);
    final i = tasks.indexWhere((t) => t.id == task.id);
    if (i != -1) {
      tasks[i] = task;
      await _saveTasksForDate(task.date, tasks);
    }
  }

  Future<void> deleteTask(Task task) async {
    final tasks = await getTasksForDate(task.date);
    tasks.removeWhere((t) => t.id == task.id);
    await _saveTasksForDate(task.date, tasks);
  }

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
