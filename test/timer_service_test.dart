import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/alarm_scheduler.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/cerebro/timer_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/datos/timer_store.dart';
import 'package:mai_ai/modelos/mai_timer.dart';
import 'package:mai_ai/modelos/task.dart';

class FakeScheduler implements AlarmScheduler {
  final Map<String, DateTime> scheduled = {};

  @override
  Future<void> init() async {}
  @override
  Future<void> ensurePermissions() async {}
  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async =>
      scheduled[id] = at;
  @override
  Future<void> cancel(String id) async => scheduled.remove(id);
}

void main() {
  late DateTime clock;
  late FakeScheduler scheduler;
  late TaskService tasks;
  late AppDatabase db;

  TimerService newService() => TimerService(
        scheduler: scheduler,
        tasks: tasks,
        store: TimerStore(db: db),
        now: () => clock,
        autoTick: false,
      );

  setUp(() {
    db = AppDatabase.memory();
    clock = DateTime(2026, 3, 4, 10, 0, 0);
    scheduler = FakeScheduler();
    tasks = TaskService(db: db);
  });

  tearDown(() => db.dispose());

  test('calcula lo que falta a partir de la hora de fin', () async {
    final service = newService();
    final t = await service.start(label: 'Té', seconds: 90);

    expect(t.remainingAt(clock), 90);
    clock = clock.add(const Duration(seconds: 30));
    expect(t.remainingAt(clock), 60);
    expect(scheduler.scheduled[t.id], DateTime(2026, 3, 4, 10, 1, 30));
  });

  test('al vencer se marca terminado y se emite la finalización', () async {
    final service = newService();
    final t = await service.start(label: 'Té', seconds: 60);
    final done = service.completions.first;

    clock = clock.add(const Duration(seconds: 61));
    await service.tick();

    expect((await done).id, t.id);
    expect(service.byId(t.id)!.status, TimerStatus.done);
  });

  test('pausar congela y continuar reprograma el aviso', () async {
    final service = newService();
    final t = await service.start(label: 'Té', seconds: 100);

    clock = clock.add(const Duration(seconds: 40));
    await service.pause(t.id);
    expect(scheduler.scheduled, isEmpty);
    expect(service.byId(t.id)!.remainingAt(clock), 60);

    clock = clock.add(const Duration(minutes: 10)); // pausado: no avanza
    expect(service.byId(t.id)!.remainingAt(clock), 60);

    await service.resume(t.id);
    expect(scheduler.scheduled[t.id], clock.add(const Duration(seconds: 60)));
  });

  test('un pomodoro de trabajo suma a la tarea una sola vez', () async {
    final task = Task.create(title: 'Estudiar', date: clock);
    await tasks.addTask(task);
    final service = newService();
    await service.start(
      label: task.title,
      seconds: 60,
      kind: TimerKind.pomodoroWork,
      taskId: task.id,
      taskDate: task.date,
    );

    clock = clock.add(const Duration(seconds: 61));
    await service.tick();
    await service.tick();

    final saved = (await tasks.getTasksForDate(task.date)).single;
    expect(saved.pomodorosCompleted, 1);
  });

  test('un descanso no suma pomodoros', () async {
    final task = Task.create(title: 'Estudiar', date: clock);
    await tasks.addTask(task);
    final service = newService();
    await service.start(
      label: task.title,
      seconds: 60,
      kind: TimerKind.pomodoroBreak,
      taskId: task.id,
      taskDate: task.date,
    );

    clock = clock.add(const Duration(seconds: 61));
    await service.tick();

    expect((await tasks.getTasksForDate(task.date)).single.pomodorosCompleted, 0);
  });

  test('lo que terminó con la app cerrada se acredita al cargar', () async {
    final task = Task.create(title: 'Estudiar', date: clock);
    await tasks.addTask(task);
    final first = newService();
    await first.start(
      label: task.title,
      seconds: 25 * 60,
      kind: TimerKind.pomodoroWork,
      taskId: task.id,
      taskDate: task.date,
    );

    // La app se cierra; pasa una hora.
    clock = clock.add(const Duration(hours: 1));
    final second = newService();
    await second.load();

    expect((await tasks.getTasksForDate(task.date)).single.pomodorosCompleted, 1);
    expect(second.latestForTask(task.id)!.status, TimerStatus.done);
  });

  test('al reabrir se reprograman los avisos de lo que sigue corriendo', () async {
    final first = newService();
    final t = await first.start(label: 'Pasta', seconds: 600);

    scheduler.scheduled.clear(); // el proceso murió y con él los avisos en memoria
    clock = clock.add(const Duration(minutes: 2));
    final second = newService();
    await second.load();

    expect(second.byId(t.id)!.status, TimerStatus.running);
    expect(scheduler.scheduled[t.id], DateTime(2026, 3, 4, 10, 10));
  });

  test('una tarea tiene un solo temporizador a la vez', () async {
    final service = newService();
    final a = await service.start(label: 'x', seconds: 60, taskId: 't1');
    final b = await service.start(label: 'x', seconds: 60, taskId: 't1');

    expect(service.byId(a.id), isNull);
    expect(service.timers.map((t) => t.id), [b.id]);
    expect(scheduler.scheduled.keys, [b.id]);
  });

  test('el id numérico de la notificación es estable y positivo', () {
    const id = '3f2b9c9e-7f0a-4c55-9d0e-1f1a2b3c4d5e';
    expect(LocalAlarmScheduler.notificationId(id), LocalAlarmScheduler.notificationId(id));
    expect(LocalAlarmScheduler.notificationId(id), isNonNegative);
    expect(
      LocalAlarmScheduler.notificationId(id),
      isNot(LocalAlarmScheduler.notificationId('otro-id')),
    );
  });
}
