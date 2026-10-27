import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../datos/app_database.dart';
import '../modelos/mai_timer.dart';
import '../modelos/task.dart';
import 'memoria_service.dart';
import 'task_service.dart';
import 'timer_service.dart';

/// Resultado de una herramienta: [json] vuelve al modelo y [resumen] se
/// muestra en el chat (null si la herramienta solo consulta).
class ResultadoHerramienta {
  const ResultadoHerramienta(this.json, [this.resumen]);
  final Map<String, dynamic> json;
  final String? resumen;
}

/// Acciones que Mai puede ejecutar desde el chat (function calling).
/// Se apoyan en los mismos servicios que usan las pantallas.
class Herramientas {
  Herramientas({
    TaskService? tasks,
    TimerService? timers,
    MemoriaService? memoria,
    DateTime Function()? now,
  })  : _tasks = tasks ?? TaskService(),
        _injectedTimers = timers,
        _memoria = memoria ?? MemoriaService(),
        _now = now ?? DateTime.now;

  final TaskService _tasks;
  final MemoriaService _memoria;
  final TimerService? _injectedTimers;
  final DateTime Function() _now;

  // Se resuelve al usarse, igual que AppDatabase.instance en los servicios.
  TimerService get _timers => _injectedTimers ?? TimerService.shared;

  /// Lo que Mai sabe del usuario, para el system prompt.
  List<String> recuerdosParaPrompt() => [for (final r in _memoria.paraPrompt()) r.text];

  /// Definiciones en el formato `tools` de la API compatible con OpenAI.
  List<Map<String, dynamic>> get esquemas => [
        _fn('crear_tarea', 'Crea una tarea en la lista del usuario.', {
          'titulo': {'type': 'string', 'description': 'Qué hay que hacer.'},
          'fecha': {'type': 'string', 'description': 'Día en formato YYYY-MM-DD. Por defecto, hoy.'},
          'pomodoros': {'type': 'integer', 'description': 'Pomodoros estimados (1 por defecto).'},
        }, ['titulo']),
        _fn('listar_tareas', 'Lista las tareas de un día.', {
          'fecha': {'type': 'string', 'description': 'Día en formato YYYY-MM-DD. Por defecto, hoy.'},
        }),
        _fn('completar_tarea', 'Marca una tarea como completada.', {
          'titulo': {'type': 'string', 'description': 'Título o parte del título de la tarea.'},
          'fecha': {'type': 'string', 'description': 'Día de la tarea (YYYY-MM-DD). Por defecto, hoy.'},
        }, ['titulo']),
        _fn('iniciar_timer', 'Inicia un temporizador que avisa al terminar.', {
          'minutos': {'type': 'number', 'description': 'Duración en minutos (admite decimales).'},
          'etiqueta': {'type': 'string', 'description': 'Para qué es el temporizador.'},
        }, ['minutos']),
        _fn('listar_timers', 'Lista los temporizadores activos o pausados.', {}),
        _fn('cancelar_timer', 'Cancela un temporizador.', {
          'etiqueta': {'type': 'string', 'description': 'Etiqueta o parte de ella. Si se omite y hay uno solo, se cancela ese.'},
        }),
        _fn('iniciar_pomodoro', 'Inicia un pomodoro de trabajo para una tarea de hoy.', {
          'titulo': {'type': 'string', 'description': 'Título o parte del título de la tarea.'},
        }, ['titulo']),
        _fn('recordar', 'Guarda un dato duradero sobre el usuario (gustos, fechas, personas, preferencias). '
            'Úsala cuando el usuario lo pida o comparta algo que valga la pena recordar.', {
          'dato': {'type': 'string', 'description': 'El dato en una frase en tercera persona, p. ej. "Su cumpleaños es el 3 de mayo".'},
        }, ['dato']),
        _fn('olvidar', 'Borra un dato que Mai recordaba sobre el usuario.', {
          'texto': {'type': 'string', 'description': 'Palabras del recuerdo a borrar.'},
        }, ['texto']),
        _fn('buscar_recuerdos', 'Busca entre todo lo que Mai recuerda del usuario.', {
          'consulta': {'type': 'string', 'description': 'Palabras a buscar.'},
        }, ['consulta']),
      ];

  static Map<String, dynamic> _fn(
    String name,
    String description,
    Map<String, dynamic> properties, [
    List<String> required = const [],
  ]) =>
      {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': {
            'type': 'object',
            'properties': properties,
            if (required.isNotEmpty) 'required': required,
          },
        },
      };

  /// Ejecuta [nombre] con los argumentos JSON que mandó el modelo. Nunca lanza:
  /// los fallos vuelven al modelo como `{"error": ...}` para que lo explique.
  Future<ResultadoHerramienta> ejecutar(String nombre, String argumentosJson) async {
    try {
      final args = argumentosJson.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(argumentosJson) as Map<String, dynamic>;
      switch (nombre) {
        case 'crear_tarea':
          return await _crearTarea(args);
        case 'listar_tareas':
          return await _listarTareas(args);
        case 'completar_tarea':
          return await _completarTarea(args);
        case 'iniciar_timer':
          return await _iniciarTimer(args);
        case 'listar_timers':
          return _listarTimers();
        case 'cancelar_timer':
          return await _cancelarTimer(args);
        case 'iniciar_pomodoro':
          return await _iniciarPomodoro(args);
        case 'recordar':
          return _recordar(args);
        case 'olvidar':
          return _olvidar(args);
        case 'buscar_recuerdos':
          return _buscarRecuerdos(args);
      }
      return ResultadoHerramienta({'error': 'Herramienta desconocida: $nombre'});
    } catch (e) {
      debugPrint('Error en la herramienta $nombre: $e');
      return ResultadoHerramienta({'error': e.toString()});
    }
  }

  DateTime _dia(Object? fecha) {
    if (fecha is String && fecha.trim().isNotEmpty) return parseDay(fecha.trim());
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  String _texto(Map<String, dynamic> args, String key) {
    final value = (args[key] as String?)?.trim() ?? '';
    if (value.isEmpty) throw ArgumentError('Falta "$key"');
    return value;
  }

  Map<String, dynamic> _tareaJson(Task t) => {
        'titulo': t.title,
        'fecha': dayString(t.date),
        'completada': t.isCompleted,
        'pomodoros': '${t.pomodorosCompleted}/${t.estimatedPomodoros}',
      };

  /// Busca por coincidencia exacta y, si no hay, por contenido.
  Future<List<Task>> _buscarTarea(String titulo, DateTime dia) async {
    final tasks = await _tasks.getTasksForDate(dia);
    final q = titulo.toLowerCase();
    final exactas = tasks.where((t) => t.title.toLowerCase() == q).toList();
    return exactas.isNotEmpty
        ? exactas
        : tasks.where((t) => t.title.toLowerCase().contains(q)).toList();
  }

  Future<ResultadoHerramienta> _crearTarea(Map<String, dynamic> args) async {
    final task = Task.create(
      title: _texto(args, 'titulo'),
      date: _dia(args['fecha']),
      estimatedPomodoros: ((args['pomodoros'] as num?)?.toInt() ?? 1).clamp(1, 20),
    );
    await _tasks.addTask(task);
    return ResultadoHerramienta(
      {'ok': true, 'tarea': _tareaJson(task)},
      'Tarea creada: ${task.title} (${dayString(task.date)})',
    );
  }

  Future<ResultadoHerramienta> _listarTareas(Map<String, dynamic> args) async {
    final dia = _dia(args['fecha']);
    final tasks = await _tasks.getTasksForDate(dia);
    return ResultadoHerramienta({
      'fecha': dayString(dia),
      'tareas': tasks.map(_tareaJson).toList(),
    });
  }

  Future<ResultadoHerramienta> _completarTarea(Map<String, dynamic> args) async {
    final titulo = _texto(args, 'titulo');
    final matches = await _buscarTarea(titulo, _dia(args['fecha']));
    if (matches.length != 1) return _ambiguo('tarea', titulo, matches.map((t) => t.title));
    final task = matches.single.copyWith(isCompleted: true);
    await _tasks.updateTask(task);
    return ResultadoHerramienta(
      {'ok': true, 'tarea': _tareaJson(task)},
      'Tarea completada: ${task.title}',
    );
  }

  Future<ResultadoHerramienta> _iniciarTimer(Map<String, dynamic> args) async {
    final minutos = (args['minutos'] as num?)?.toDouble() ?? 0;
    final seconds = (minutos * 60).round();
    if (seconds <= 0) throw ArgumentError('"minutos" debe ser mayor que 0');
    final etiqueta = (args['etiqueta'] as String?)?.trim();
    final label = etiqueta == null || etiqueta.isEmpty ? 'Temporizador' : etiqueta;
    final timer = await _timers.start(label: label, seconds: seconds);
    return ResultadoHerramienta(
      {'ok': true, 'timer': _timerJson(timer)},
      'Timer iniciado: $label (${_duracion(seconds)})',
    );
  }

  List<MaiTimer> get _activos =>
      _timers.timers.where((t) => t.status != TimerStatus.done).toList();

  ResultadoHerramienta _listarTimers() =>
      ResultadoHerramienta({'timers': _activos.map(_timerJson).toList()});

  Future<ResultadoHerramienta> _cancelarTimer(Map<String, dynamic> args) async {
    final q = (args['etiqueta'] as String?)?.trim().toLowerCase() ?? '';
    final activos = _activos;
    final matches = q.isEmpty
        ? activos
        : activos.where((t) => t.label.toLowerCase().contains(q)).toList();
    if (matches.length != 1) return _ambiguo('temporizador', q, matches.map((t) => t.label));
    final timer = matches.single;
    await _timers.remove(timer.id);
    return ResultadoHerramienta({'ok': true}, 'Timer cancelado: ${timer.label}');
  }

  Future<ResultadoHerramienta> _iniciarPomodoro(Map<String, dynamic> args) async {
    final titulo = _texto(args, 'titulo');
    final matches = await _buscarTarea(titulo, _dia(null));
    if (matches.length != 1) return _ambiguo('tarea', titulo, matches.map((t) => t.title));
    final task = matches.single;
    final settings = await _tasks.getPomodoroSettings();
    final seconds = settings.work * 60;
    final timer = await _timers.start(
      label: task.title,
      seconds: seconds,
      kind: TimerKind.pomodoroWork,
      taskId: task.id,
      taskDate: task.date,
    );
    return ResultadoHerramienta(
      {'ok': true, 'timer': _timerJson(timer)},
      'Pomodoro iniciado: ${task.title} (${_duracion(seconds)})',
    );
  }

  ResultadoHerramienta _recordar(Map<String, dynamic> args) {
    final recuerdo = _memoria.recordar(_texto(args, 'dato'));
    return ResultadoHerramienta({'ok': true, 'recuerdo': recuerdo.text}, 'Recordado: ${recuerdo.text}');
  }

  ResultadoHerramienta _olvidar(Map<String, dynamic> args) {
    final texto = _texto(args, 'texto');
    final matches = _memoria.buscar(texto);
    if (matches.length != 1) return _ambiguo('recuerdo', texto, matches.map((r) => r.text));
    _memoria.olvidar(matches.single.id);
    return ResultadoHerramienta({'ok': true}, 'Olvidado: ${matches.single.text}');
  }

  ResultadoHerramienta _buscarRecuerdos(Map<String, dynamic> args) => ResultadoHerramienta({
        'recuerdos': [for (final r in _memoria.buscar(_texto(args, 'consulta'))) r.text],
      });

  ResultadoHerramienta _ambiguo(String que, String busqueda, Iterable<String> opciones) =>
      ResultadoHerramienta({
        'error': opciones.isEmpty
            ? 'No encontré ningún $que que coincida con "$busqueda".'
            : 'Hay varios $que que coinciden; pide al usuario que elija uno.',
        if (opciones.isNotEmpty) 'opciones': opciones.toList(),
      });

  Map<String, dynamic> _timerJson(MaiTimer t) => {
        'etiqueta': t.label,
        'tipo': t.kind.name,
        'estado': t.status.name,
        'restante': _duracion(t.remainingAt(_timers.now)),
      };

  static String _duracion(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s s';
    return s == 0 ? '$m min' : '$m min $s s';
  }
}
