import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/persistencia_service.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/datos/remote_store.dart';
import 'package:mai_ai/datos/sync_service.dart';
import 'package:mai_ai/modelos/chat_message.dart';
import 'package:mai_ai/modelos/task.dart';

/// Servidor falso con la misma lógica que las tablas de Supabase: guarda filas
/// por id y les pone un `server_updated_at` que siempre crece.
class FakeRemote implements RemoteStore {
  bool configured = true;
  bool offline = false;
  int _clock = 0;
  final Map<String, Map<String, Map<String, dynamic>>> tables = {};
  int upsertCalls = 0;

  @override
  Future<bool> prepare() async {
    if (offline) throw Exception('sin red');
    return configured;
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    if (offline) throw Exception('sin red');
    upsertCalls++;
    final store = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      _clock++;
      store[r['id'] as String] = {
        ...r,
        'server_updated_at': '2026-01-01T00:00:${_clock.toString().padLeft(2, '0')}+00:00',
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    String? since,
    required int limit,
  }) async {
    if (offline) throw Exception('sin red');
    final rows = (tables[table]?.values.toList() ?? [])
      ..sort((a, b) =>
          (a['server_updated_at'] as String).compareTo(b['server_updated_at'] as String));
    return rows
        .where((r) => since == null || (r['server_updated_at'] as String).compareTo(since) >= 0)
        .take(limit)
        .toList();
  }
}

void main() {
  late AppDatabase phone;
  late AppDatabase desktop;
  late FakeRemote remote;
  late SyncService phoneSync;
  late SyncService desktopSync;

  setUp(() {
    phone = AppDatabase.memory();
    desktop = AppDatabase.memory();
    remote = FakeRemote();
    phoneSync = SyncService(remote: remote, db: phone);
    desktopSync = SyncService(remote: remote, db: desktop);
  });

  tearDown(() {
    phoneSync.dispose();
    desktopSync.dispose();
    phone.dispose();
    desktop.dispose();
  });

  final day = DateTime(2026, 3, 4);

  test('sin configuración queda desactivada y no toca nada', () async {
    remote.configured = false;
    await TaskService(db: phone).addTask(Task.create(title: 'A', date: day));

    await phoneSync.sync();

    expect(phoneSync.status, SyncStatus.disabled);
    expect(remote.upsertCalls, 0);
  });

  test('lo creado en un dispositivo aparece en el otro', () async {
    final task = Task.create(title: 'Estudiar', date: day, estimatedPomodoros: 3);
    await TaskService(db: phone).addTask(task);
    await PersistenciaService(db: phone).guardarMensajes([ChatMessage.user(text: 'hola')]);

    await phoneSync.sync();
    final changed = desktopSync.remoteChanges.first;
    await desktopSync.sync();

    final tasks = await TaskService(db: desktop).getTasksForDate(day);
    expect(tasks.single.id, task.id);
    expect(tasks.single.title, 'Estudiar');
    expect(tasks.single.estimatedPomodoros, 3);
    expect((await PersistenciaService(db: desktop).cargarMensajes()).single.text, 'hola');
    expect(await changed, containsAll(['tasks', 'messages']));
  });

  test('sin conexión los cambios quedan pendientes y se envían al volver', () async {
    final service = TaskService(db: phone);
    remote.offline = true;
    await service.addTask(Task.create(title: 'Offline', date: day));

    await phoneSync.sync();
    expect(phoneSync.status, SyncStatus.failed);
    expect(phone.db.select('SELECT * FROM tasks WHERE dirty = 1'), hasLength(1));

    remote.offline = false;
    await phoneSync.sync();
    expect(phoneSync.status, SyncStatus.idle);
    expect(phone.db.select('SELECT * FROM tasks WHERE dirty = 1'), isEmpty);
    expect(remote.tables['tasks'], hasLength(1));
  });

  test('si se edita en ambos lados gana la edición más reciente', () async {
    final task = Task.create(title: 'Original', date: day);
    await TaskService(db: phone).addTask(task);
    await phoneSync.sync();
    await desktopSync.sync();

    // Edición vieja en el teléfono, más nueva en el escritorio.
    await TaskService(db: phone).updateTask(task.copyWith(title: 'Del teléfono'));
    phone.db.execute('UPDATE tasks SET updated_at = updated_at - 5000');
    await TaskService(db: desktop).updateTask(task.copyWith(title: 'Del escritorio'));

    await desktopSync.sync();
    await phoneSync.sync();
    await desktopSync.sync();

    for (final db in [phone, desktop]) {
      expect((await TaskService(db: db).getTasksForDate(day)).single.title, 'Del escritorio');
    }
  });

  test('un borrado llega al otro dispositivo', () async {
    final task = Task.create(title: 'Borrar', date: day);
    await TaskService(db: phone).addTask(task);
    await phoneSync.sync();
    await desktopSync.sync();
    expect(await TaskService(db: desktop).getTasksForDate(day), hasLength(1));

    await TaskService(db: phone).deleteTask(task);
    await phoneSync.sync();
    await desktopSync.sync();

    expect(await TaskService(db: desktop).getTasksForDate(day), isEmpty);
  });

  test('lo ya sincronizado no se vuelve a subir', () async {
    await TaskService(db: phone).addTask(Task.create(title: 'A', date: day));
    await phoneSync.sync();
    final calls = remote.upsertCalls;

    await phoneSync.sync(); // baja su propio eco, no hay nada nuevo que subir

    expect(remote.upsertCalls, calls);
    expect(phone.db.select('SELECT * FROM tasks WHERE dirty = 1'), isEmpty);
  });

  test('limpiar el chat se propaga', () async {
    final chat = PersistenciaService(db: phone);
    await chat.guardarMensajes([ChatMessage.user(text: 'uno'), ChatMessage.assistant(text: 'dos')]);
    await phoneSync.sync();
    await desktopSync.sync();
    expect(await PersistenciaService(db: desktop).cargarMensajes(), hasLength(2));

    await chat.limpiarMensajes();
    await phoneSync.sync();
    await desktopSync.sync();

    expect(await PersistenciaService(db: desktop).cargarMensajes(), isEmpty);
  });
}
