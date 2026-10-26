import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/modelos/task.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.dispose());

  test('Task sobrevive a toJson/fromJson', () {
    final t = Task.create(title: 'Estudiar', date: DateTime(2026, 3, 4, 15, 30), estimatedPomodoros: 3)
        .copyWith(isCompleted: true, pomodorosCompleted: 2);
    final back = Task.fromJson(t.toJson());

    expect(back.id, t.id);
    expect(back.title, 'Estudiar');
    expect(back.date, DateTime(2026, 3, 4));
    expect(back.isCompleted, isTrue);
    expect(back.pomodorosCompleted, 2);
    expect(back.estimatedPomodoros, 3);
  });

  test('TaskService agrega, actualiza y borra por día', () async {
    final service = TaskService(db: db);
    final day = DateTime(2026, 3, 4);
    final task = Task.create(title: 'A', date: day);

    await service.addTask(task);
    expect((await service.getTasksForDate(day)).map((t) => t.title), ['A']);
    expect(await service.getTasksForDate(DateTime(2026, 3, 5)), isEmpty);

    await service.updateTask(task.copyWith(title: 'B'));
    expect((await service.getTasksForDate(day)).single.title, 'B');

    await service.deleteTask(task);
    expect(await service.getTasksForDate(day), isEmpty);
  });
}
