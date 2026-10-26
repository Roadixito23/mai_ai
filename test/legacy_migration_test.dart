import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/persistencia_service.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/datos/legacy_migration.dart';
import 'package:mai_ai/datos/timer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.dispose());

  test('importa chat, tareas y timers con UUID y deja todo pendiente de subir', () async {
    SharedPreferences.setMockInitialValues({
      'chat_messages': jsonEncode([
        {'id': '1', 'text': 'hola', 'isUser': true, 'timestamp': '2026-03-04T10:00:00.000'},
        {'id': '2', 'text': 'hey', 'isUser': false, 'timestamp': '2026-03-04T10:00:05.000'},
        {'id': '3', 'text': 'error', 'isUser': false, 'isError': true, 'timestamp': '2026-03-04T10:00:06.000'},
      ]),
      'tasks_2026-03-04': jsonEncode([
        {
          'id': '1700000000000',
          'title': 'Estudiar',
          'date': '2026-03-04T00:00:00.000',
          'isCompleted': true,
          'pomodorosCompleted': 2,
          'estimatedPomodoros': 3,
        },
      ]),
      'mai_timers': jsonEncode([
        {
          'id': 'a1b2c3d4-0000-4000-8000-000000000001',
          'label': 'Estudiar',
          'kind': 'pomodoroWork',
          'durationSeconds': 1500,
          'status': 'paused',
          'endsAt': null,
          'remainingSeconds': 600,
          'taskId': '1700000000000',
          'taskDate': '2026-03-04T00:00:00.000',
          'handled': false,
          'updatedAt': '2026-03-04T10:00:00.000Z',
        },
      ]),
      'pomodoro_work_minutes': 40, // preferencia local: debe quedar intacta
    });

    await LegacyMigration.run(db);

    final messages = await PersistenciaService(db: db).cargarMensajes();
    expect(messages.map((m) => m.text), ['hola', 'hey']); // el error no se importa

    final tasks = await TaskService(db: db).getTasksForDate(DateTime(2026, 3, 4));
    expect(tasks.single.title, 'Estudiar');
    expect(tasks.single.isCompleted, isTrue);
    expect(tasks.single.pomodorosCompleted, 2);
    expect(tasks.single.id, isNot('1700000000000'));
    expect(tasks.single.id, hasLength(36)); // UUID

    final timer = TimerStore(db: db).loadAll().single;
    expect(timer.taskId, tasks.single.id); // sigue apuntando a su tarea
    expect(timer.remainingSeconds, 600);

    expect(db.db.select('SELECT * FROM tasks WHERE dirty = 0'), isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'pomodoro_work_minutes'});
  });

  test('corre una sola vez', () async {
    SharedPreferences.setMockInitialValues({
      'tasks_2026-03-04': jsonEncode([
        {'id': '1', 'title': 'A', 'date': '2026-03-04T00:00:00.000'},
      ]),
    });
    await LegacyMigration.run(db);

    SharedPreferences.setMockInitialValues({
      'tasks_2026-03-05': jsonEncode([
        {'id': '2', 'title': 'B', 'date': '2026-03-05T00:00:00.000'},
      ]),
    });
    await LegacyMigration.run(db);

    expect(db.db.select('SELECT * FROM tasks'), hasLength(1));
  });

  test('sin datos antiguos no hace nada', () async {
    SharedPreferences.setMockInitialValues({});
    await LegacyMigration.run(db);
    expect(db.db.select('SELECT * FROM tasks'), isEmpty);
  });
}
