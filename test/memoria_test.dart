import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/herramientas.dart';
import 'package:mai_ai/cerebro/mai_personalidad.dart';
import 'package:mai_ai/cerebro/memoria_service.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/datos/sync_schema.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;
  late MemoriaService memoria;

  setUp(() {
    db = AppDatabase.memory();
    memoria = MemoriaService(db: db);
  });
  tearDown(() => db.dispose());

  group('MemoriaService', () {
    test('recuerda sin duplicar y queda pendiente de sincronizar', () {
      memoria.recordar('Su cumpleaños es el 3 de mayo');
      memoria.recordar('  su cumpleaños es el 3 de MAYO ');

      expect(memoria.listar().map((r) => r.text), ['Su cumpleaños es el 3 de mayo']);
      expect(db.db.select('SELECT dirty FROM memories').single['dirty'], 1);
    });

    test('rechaza recuerdos vacíos', () {
      expect(() => memoria.recordar('   '), throwsArgumentError);
    });

    test('buscar exige todas las palabras, sin importar mayúsculas', () {
      memoria.recordar('Su perra se llama Luna');
      memoria.recordar('Prefiere pomodoros de 50 minutos');
      expect(memoria.buscar('LUNA perra').map((r) => r.text), ['Su perra se llama Luna']);
      expect(memoria.buscar('luna gato'), isEmpty);
    });

    test('olvidar es un borrado lógico', () {
      final r = memoria.recordar('Vive en Santiago');
      memoria.olvidar(r.id);

      expect(memoria.listar(), isEmpty);
      final row = db.db.select('SELECT deleted_at, dirty FROM memories').single;
      expect(row['deleted_at'], isNotNull);
      expect(row['dirty'], 1);
    });

    test('paraPrompt se queda con los más recientes', () {
      for (var i = 0; i < MemoriaService.maxEnPrompt + 5; i++) {
        memoria.recordar('dato $i');
      }
      final enPrompt = memoria.paraPrompt();
      expect(enPrompt, hasLength(MemoriaService.maxEnPrompt));
      expect(enPrompt.last.text, 'dato ${MemoriaService.maxEnPrompt + 4}');
    });
  });

  group('herramientas de memoria', () {
    late Herramientas tools;
    setUp(() => tools = Herramientas(tasks: TaskService(db: db), memoria: memoria));

    Future<ResultadoHerramienta> run(String name, Map<String, dynamic> args) =>
        tools.ejecutar(name, jsonEncode(args));

    test('recordar, buscar y olvidar', () async {
      final r = await run('recordar', {'dato': 'Le gusta el café sin azúcar'});
      expect(r.resumen, 'Recordado: Le gusta el café sin azúcar');
      expect(tools.recuerdosParaPrompt(), ['Le gusta el café sin azúcar']);

      final b = await run('buscar_recuerdos', {'consulta': 'café'});
      expect(b.json['recuerdos'], ['Le gusta el café sin azúcar']);
      expect(b.resumen, isNull);

      final o = await run('olvidar', {'texto': 'café'});
      expect(o.resumen, 'Olvidado: Le gusta el café sin azúcar');
      expect(tools.recuerdosParaPrompt(), isEmpty);
    });

    test('olvidar con varias coincidencias pide elegir', () async {
      memoria.recordar('Su hermana se llama Ana');
      memoria.recordar('Su hermana vive en Lima');
      final o = await run('olvidar', {'texto': 'hermana'});
      expect(o.json['opciones'], hasLength(2));
      expect(memoria.listar(), hasLength(2));
    });
  });

  test('el prompt incluye los recuerdos solo si hay', () {
    final now = DateTime(2026, 10, 27, 9, 30);
    expect(MaiPersonalidad.build(now), isNot(contains('Lo que sabes del usuario')));
    final p = MaiPersonalidad.build(now, recuerdos: ['Su perra se llama Luna']);
    expect(p, contains('Lo que sabes del usuario'));
    expect(p, contains('- Su perra se llama Luna'));
  });

  test('la tabla memories se sincroniza', () {
    expect(syncTables.map((t) => t.name), contains('memories'));
  });

  test('una base v1 existente migra a v2 sin perder datos', () {
    // Base como la dejaba la versión anterior de la app (solo la tabla tasks basta).
    final raw = sqlite3.openInMemory()
      ..execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, date TEXT NOT NULL, '
          'is_completed INTEGER NOT NULL DEFAULT 0, pomodoros_completed INTEGER NOT NULL DEFAULT 0, '
          'estimated_pomodoros INTEGER NOT NULL DEFAULT 1, updated_at INTEGER NOT NULL, '
          'deleted_at INTEGER, dirty INTEGER NOT NULL DEFAULT 1)')
      ..execute("INSERT INTO tasks (id, title, date, updated_at) VALUES ('t1', 'Vieja', '2026-10-01', 1)")
      ..userVersion = 1;

    final migrated = AppDatabase.wrap(raw);
    expect(migrated.db.userVersion, 2);
    expect(migrated.db.select('SELECT title FROM tasks').single['title'], 'Vieja');
    MemoriaService(db: migrated).recordar('funciona');
    expect(MemoriaService(db: migrated).listar().single.text, 'funciona');
    migrated.dispose();
  });
}
