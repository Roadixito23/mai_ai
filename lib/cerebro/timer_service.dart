import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../datos/timer_store.dart';
import '../modelos/mai_timer.dart';
import 'alarm_scheduler.dart';
import 'task_service.dart';

/// Temporizadores y pomodoros. Funciona sin conexión: todo el estado vive en el
/// dispositivo y los avisos los programa el sistema (ver [AlarmScheduler]).
class TimerService extends ChangeNotifier {
  TimerService({
    AlarmScheduler? scheduler,
    TaskService? tasks,
    TimerStore? store,
    DateTime Function()? now,
    bool autoTick = true,
  })  : _scheduler = scheduler ?? LocalAlarmScheduler(),
        _tasks = tasks ?? TaskService(),
        _store = store ?? TimerStore(),
        _now = now ?? DateTime.now,
        _autoTick = autoTick;

  /// Instancia compartida por toda la app.
  static final TimerService shared = TimerService();

  static const Duration _keepFinished = Duration(days: 1);

  final AlarmScheduler _scheduler;
  final TaskService _tasks;
  final TimerStore _store;
  final DateTime Function() _now;
  final bool _autoTick;
  final _uuid = const Uuid();

  final List<MaiTimer> _timers = [];
  final _completions = StreamController<MaiTimer>.broadcast();
  Timer? _ticker;
  bool _ticking = false;

  List<MaiTimer> get timers => List.unmodifiable(_timers);

  /// Emite cada vez que un temporizador termina (también los que terminaron
  /// con la app cerrada, al volver a abrirla).
  Stream<MaiTimer> get completions => _completions.stream;

  DateTime get now => _now();

  MaiTimer? byId(String id) {
    for (final t in _timers) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// El temporizador más reciente de una tarea, esté corriendo o terminado.
  MaiTimer? latestForTask(String taskId) {
    MaiTimer? latest;
    for (final t in _timers) {
      if (t.taskId == taskId &&
          (latest == null || t.updatedAt.isAfter(latest.updatedAt))) {
        latest = t;
      }
    }
    return latest;
  }

  /// Carga los temporizadores de la base local. También se usa tras una
  /// sincronización, cuando pudieron llegar timers de otro dispositivo.
  Future<void> load() async {
    await _scheduler.init();
    _timers
      ..clear()
      ..addAll(_store.loadAll());

    final cutoff = now.subtract(_keepFinished);
    for (final t in _timers.where(
      (t) => t.status == TimerStatus.done && t.handled && t.updatedAt.isBefore(cutoff),
    ).toList()) {
      _store.softDelete(t.id);
      _timers.remove(t);
    }

    // Lo que terminó mientras la app estaba cerrada, y avisos de lo que sigue.
    for (final t in List.of(_timers)) {
      if (t.isDueAt(now)) {
        await _complete(t);
      } else if (t.status == TimerStatus.running) {
        await _scheduleAlarm(t);
      } else if (t.status == TimerStatus.done && !t.handled) {
        await _complete(t, alreadyDone: true);
      }
    }
    _save();
    _syncTicker();
    notifyListeners();
  }

  Future<MaiTimer> start({
    required String label,
    required int seconds,
    TimerKind kind = TimerKind.custom,
    String? taskId,
    DateTime? taskDate,
  }) async {
    assert(seconds > 0);
    await _scheduler.ensurePermissions();

    // Una tarea tiene un solo temporizador a la vez.
    if (taskId != null) {
      for (final old in _timers.where((t) => t.taskId == taskId).toList()) {
        await _scheduler.cancel(old.id);
        _store.softDelete(old.id);
        _timers.remove(old);
      }
    }

    final timer = MaiTimer(
      id: _uuid.v4(),
      label: label,
      kind: kind,
      durationSeconds: seconds,
      status: TimerStatus.running,
      endsAt: now.add(Duration(seconds: seconds)),
      taskId: taskId,
      taskDate: taskDate,
      updatedAt: now,
    );
    _timers.add(timer);
    await _scheduleAlarm(timer);
    _save();
    _syncTicker();
    notifyListeners();
    return timer;
  }

  Future<void> pause(String id) async {
    final t = byId(id);
    if (t == null || t.status != TimerStatus.running) return;
    await _scheduler.cancel(id);
    _replace(t.copyWith(
      status: TimerStatus.paused,
      remainingSeconds: t.remainingAt(now),
      clearEndsAt: true,
      updatedAt: now,
    ));
    _save();
    _syncTicker();
    notifyListeners();
  }

  Future<void> resume(String id) async {
    final t = byId(id);
    if (t == null || t.status != TimerStatus.paused) return;
    final resumed = t.copyWith(
      status: TimerStatus.running,
      endsAt: now.add(Duration(seconds: t.remainingSeconds ?? t.durationSeconds)),
      clearRemaining: true,
      updatedAt: now,
    );
    _replace(resumed);
    await _scheduleAlarm(resumed);
    _save();
    _syncTicker();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _scheduler.cancel(id);
    _timers.removeWhere((t) => t.id == id);
    _store.softDelete(id);
    _syncTicker();
    notifyListeners();
  }

  /// Revisa qué temporizadores ya vencieron. Lo llama el reloj interno cada
  /// segundo; es público para poder probarlo con un reloj falso.
  Future<void> tick() async {
    // Sin esto, un tick lento volvería a completar (y sumar) el mismo pomodoro.
    if (_ticking) return;
    _ticking = true;
    try {
      var changed = false;
      for (final t in List.of(_timers)) {
        if (t.isDueAt(now)) {
          await _complete(t);
          changed = true;
        }
      }
      if (changed) _save();
      _syncTicker();
      notifyListeners(); // refresca las cuentas regresivas
    } finally {
      _ticking = false;
    }
  }

  Future<void> _complete(MaiTimer timer, {bool alreadyDone = false}) async {
    var done = alreadyDone
        ? timer
        : timer.copyWith(
            status: TimerStatus.done,
            clearEndsAt: true,
            clearRemaining: true,
            updatedAt: now,
          );

    var handled = true;
    if (timer.kind == TimerKind.pomodoroWork && timer.taskId != null && !timer.handled) {
      handled = await _creditPomodoro(timer);
    }
    done = done.copyWith(handled: handled, updatedAt: done.updatedAt);
    _replace(done);
    _completions.add(done);
  }

  /// Suma el pomodoro a la tarea leyéndola de nuevo, para no pisar cambios.
  Future<bool> _creditPomodoro(MaiTimer timer) async {
    try {
      final date = timer.taskDate ?? now;
      final tasks = await _tasks.getTasksForDate(date);
      final i = tasks.indexWhere((t) => t.id == timer.taskId);
      if (i == -1) return true; // la tarea ya no existe
      await _tasks.updateTask(
        tasks[i].copyWith(pomodorosCompleted: tasks[i].pomodorosCompleted + 1),
      );
      return true;
    } catch (e) {
      debugPrint('No se pudo sumar el pomodoro: $e');
      return false;
    }
  }

  Future<void> _scheduleAlarm(MaiTimer t) {
    final (title, body) = switch (t.kind) {
      TimerKind.pomodoroWork => ('Pomodoro terminado', 'Hora de descansar: ${t.label}'),
      TimerKind.pomodoroBreak => ('Descanso terminado', 'Vuelve a: ${t.label}'),
      TimerKind.custom => (t.label, 'Tu temporizador terminó'),
    };
    return _scheduler.schedule(id: t.id, title: title, body: body, at: t.endsAt!);
  }

  void _replace(MaiTimer updated) {
    final i = _timers.indexWhere((t) => t.id == updated.id);
    if (i != -1) _timers[i] = updated;
  }

  /// El reloj interno solo corre mientras haya algo contando.
  void _syncTicker() {
    final anyRunning = _timers.any((t) => t.status == TimerStatus.running);
    if (anyRunning && _autoTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } else if (!anyRunning) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _save() {
    for (final t in _timers) {
      _store.upsert(t);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _completions.close();
    super.dispose();
  }
}
