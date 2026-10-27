import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/herramientas.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/cerebro/timer_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/datos/timer_store.dart';
import 'package:mai_ai/modelos/mai_timer.dart';
import 'package:mai_ai/modelos/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'timer_service_test.dart' show FakeScheduler;

void main() {
  final clock = DateTime(2026, 3, 4, 10, 0, 0);
  late AppDatabase db;
  late TaskService tasks;
  late TimerService timers;
  late Herramientas tools;

  setUp(() {
    SharedPreferences.setMockInitialValues({}); // ajustes del pomodoro
    db = AppDatabase.memory();
    tasks = TaskService(db: db);
    timers = TimerService(
      scheduler: FakeScheduler(),
      tasks: tasks,
      store: TimerStore(db: db),
      now: () => clock,
      autoTick: false,
    );
    tools = Herramientas(tasks: tasks, timers: timers, now: () => clock);
  });

  tearDown(() => db.dispose());

  Future<ResultadoHerramienta> run(String name, [Map<String, dynamic> args = const {}]) =>
      tools.ejecutar(name, jsonEncode(args));

  test('cada herramienta tiene un esquema de función', () {
    final names = tools.esquemas.map((e) => e['function']['name']).toSet();
    expect(names, containsAll(['crear_tarea', 'listar_tareas', 'completar_tarea',
        'iniciar_timer', 'listar_timers', 'cancelar_timer', 'iniciar_pomodoro']));
  });

  test('crear_tarea usa hoy por defecto y respeta la fecha dada', () async {
    final hoy = await run('crear_tarea', {'titulo': 'Revisar correo'});
    await run('crear_tarea', {'titulo': 'Dentista', 'fecha': '2026-03-05', 'pomodoros': 2});

    expect(hoy.resumen, contains('Revisar correo'));
    expect((await tasks.getTasksForDate(clock)).map((t) => t.title), ['Revisar correo']);
    final manana = await tasks.getTasksForDate(DateTime(2026, 3, 5));
    expect(manana.single.estimatedPomodoros, 2);
  });

  test('listar_tareas no genera resumen para el chat', () async {
    await tasks.addTask(Task.create(title: 'Leer', date: clock));
    final r = await run('listar_tareas');
    expect(r.resumen, isNull);
    expect((r.json['tareas'] as List).single['titulo'], 'Leer');
  });

  test('completar_tarea encuentra por parte del título', () async {
    await tasks.addTask(Task.create(title: 'Pagar la luz', date: clock));
    final r = await run('completar_tarea', {'titulo': 'luz'});
    expect(r.json['ok'], isTrue);
    expect((await tasks.getTasksForDate(clock)).single.isCompleted, isTrue);
  });

  test('completar_tarea con varias coincidencias pide elegir', () async {
    await tasks.addTask(Task.create(title: 'Llamar a mamá', date: clock));
    await tasks.addTask(Task.create(title: 'Llamar al banco', date: clock));
    final r = await run('completar_tarea', {'titulo': 'llamar'});
    expect(r.json['error'], isNotNull);
    expect(r.json['opciones'], hasLength(2));
    expect(r.resumen, isNull);
  });

  test('iniciar_timer y cancelar_timer', () async {
    final r = await run('iniciar_timer', {'minutos': 1.5, 'etiqueta': 'Té'});
    expect(r.resumen, 'Timer iniciado: Té (1 min 30 s)');
    expect(timers.timers.single.durationSeconds, 90);

    final c = await run('cancelar_timer', {'etiqueta': 'té'});
    expect(c.json['ok'], isTrue);
    expect(timers.timers, isEmpty);
  });

  test('iniciar_timer rechaza duraciones no positivas', () async {
    final r = await run('iniciar_timer', {'minutos': 0});
    expect(r.json['error'], isNotNull);
    expect(timers.timers, isEmpty);
  });

  test('iniciar_pomodoro liga el timer a la tarea', () async {
    final task = Task.create(title: 'Estudiar', date: clock);
    await tasks.addTask(task);
    await run('iniciar_pomodoro', {'titulo': 'estudiar'});

    final t = timers.timers.single;
    expect(t.kind, TimerKind.pomodoroWork);
    expect(t.taskId, task.id);
    expect(t.durationSeconds, 25 * 60);
  });

  test('argumentos inválidos y herramientas desconocidas devuelven error sin lanzar', () async {
    expect((await tools.ejecutar('crear_tarea', '{no es json')).json['error'], isNotNull);
    expect((await run('crear_tarea')).json['error'], isNotNull);
    expect((await run('hackear')).json['error'], isNotNull);
  });
}
