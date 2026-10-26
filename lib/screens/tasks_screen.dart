import 'dart:async';
import 'package:flutter/material.dart';
import '../modelos/mai_timer.dart';
import '../modelos/task.dart';
import '../cerebro/task_service.dart';
import '../cerebro/timer_service.dart';
import '../datos/sync_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskService _service = TaskService();
  List<Task> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  int _workMinutes = 25;
  int _breakMinutes = 5;
  StreamSubscription<MaiTimer>? _completionSub;
  StreamSubscription<Set<String>>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Un pomodoro puede terminar con la hoja cerrada: se refleja en la lista.
    _completionSub = TimerService.shared.completions.listen((_) => _loadTasks());
    // Y los cambios hechos desde otro dispositivo.
    _syncSub = SyncService.shared.remoteChanges.listen((tables) {
      if (tables.contains('tasks')) _loadTasks();
    });
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final settings = await _service.getPomodoroSettings();
    final tasks = await _service.getTasksForDate(_selectedDate);
    setState(() {
      _workMinutes = settings.work;
      _breakMinutes = settings.rest;
      _tasks = tasks;
    });
  }

  Future<void> _loadTasks() async {
    final tasks = await _service.getTasksForDate(_selectedDate);
    setState(() => _tasks = tasks);
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _tasks = [];
    });
    _loadTasks();
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }

  // --- Acciones de tareas ---

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    int estimated = 1;
    DateTime pickedDate = _selectedDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Descripcion de la tarea'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Pomodoros estimados:'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: estimated > 1
                        ? () => setLocal(() => estimated--)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text('$estimated', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: estimated < 12
                        ? () => setLocal(() => estimated++)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_dateLabel(pickedDate)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setLocal(() => pickedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      final task = Task.create(
        title: titleController.text.trim(),
        date: pickedDate,
        estimatedPomodoros: estimated,
      );
      await _service.addTask(task);
      // Recargar solo si la tarea fue creada para la fecha seleccionada
      final dayKey = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      final selKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      if (dayKey == selKey) _loadTasks();
    }
  }

  Future<void> _toggleCompleted(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await _service.updateTask(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    await _service.deleteTask(task);
    _loadTasks();
  }

  void _startPomodoro(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PomodoroSheet(
        task: task,
        workMinutes: _workMinutes,
        breakMinutes: _breakMinutes,
        onSettingsSaved: (work, rest) async {
          await _service.savePomodoroSettings(work, rest);
          setState(() {
            _workMinutes = work;
            _breakMinutes = rest;
          });
        },
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _tasks.where((t) => !t.isCompleted).length;
    final done = _tasks.where((t) => t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // --- Selector de fecha ---
          Container(
            color: theme.colorScheme.inversePrimary,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _tasks = [];
                      });
                      _loadTasks();
                    }
                  },
                  child: Text(
                    _dateLabel(_selectedDate),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1),
                ),
              ],
            ),
          ),

          // --- Resumen ---
          if (_tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '$pending pendiente${pending != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$done completada${done != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ),

          // --- Lista ---
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Sin tareas para este dia',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) => _TaskTile(
                      task: _tasks[i],
                      onToggle: () => _toggleCompleted(_tasks[i]),
                      onDelete: () => _deleteTask(_tasks[i]),
                      onPomodoro: () => _startPomodoro(_tasks[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de tarea
// ---------------------------------------------------------------------------

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onPomodoro;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onPomodoro,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.isCompleted;
    final hasPomToDo = task.pomodorosCompleted < task.estimatedPomodoros;

    return ListTile(
      leading: Checkbox(
        value: done,
        onChanged: (_) => onToggle(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? Colors.grey : null,
        ),
      ),
      subtitle: _PomodoroIndicator(
        completed: task.pomodorosCompleted,
        total: task.estimatedPomodoros,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!done && hasPomToDo)
            IconButton(
              icon: const Text('🍅', style: TextStyle(fontSize: 20)),
              onPressed: onPomodoro,
              tooltip: 'Iniciar pomodoro',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PomodoroIndicator extends StatelessWidget {
  final int completed;
  final int total;

  const _PomodoroIndicator({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: List.generate(total, (i) {
          final isDone = i < completed;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? Colors.deepOrange : Colors.grey[300],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet del Pomodoro
// ---------------------------------------------------------------------------

class _PomodoroSheet extends StatefulWidget {
  final Task task;
  final int workMinutes;
  final int breakMinutes;
  final void Function(int work, int rest) onSettingsSaved;

  const _PomodoroSheet({
    required this.task,
    required this.workMinutes,
    required this.breakMinutes,
    required this.onSettingsSaved,
  });

  @override
  State<_PomodoroSheet> createState() => _PomodoroSheetState();
}

class _PomodoroSheetState extends State<_PomodoroSheet> {
  final TimerService _timers = TimerService.shared;
  final TaskService _taskService = TaskService();
  late Task _task;
  late int _workMinutes;
  late int _breakMinutes;
  StreamSubscription<MaiTimer>? _completionSub;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _workMinutes = widget.workMinutes;
    _breakMinutes = widget.breakMinutes;
    // El servicio suma el pomodoro a la tarea; aquí solo se vuelve a leer.
    _completionSub = _timers.completions
        .where((t) => t.taskId == _task.id)
        .listen((_) => _reloadTask());
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    super.dispose();
  }

  Future<void> _reloadTask() async {
    final tasks = await _taskService.getTasksForDate(_task.date);
    final fresh = tasks.where((t) => t.id == _task.id).firstOrNull;
    if (fresh != null && mounted) setState(() => _task = fresh);
  }

  /// El estado sale del temporizador guardado, no de variables del widget:
  /// así la hoja es correcta aunque se cierre y se vuelva a abrir.
  MaiTimer? get _current => _timers.latestForTask(_task.id);

  bool get _isRunning => _current?.status == TimerStatus.running;
  bool get _isPaused => _current?.status == TimerStatus.paused;

  bool get _isWorking {
    final c = _current;
    if (c == null) return true;
    if (c.status == TimerStatus.done) return c.kind == TimerKind.pomodoroBreak;
    return c.kind == TimerKind.pomodoroWork;
  }

  int get _phaseSeconds => (_isWorking ? _workMinutes : _breakMinutes) * 60;

  int get _totalSeconds {
    final c = _current;
    return (_isRunning || _isPaused) ? c!.durationSeconds : _phaseSeconds;
  }

  int get _remainingSeconds {
    final c = _current;
    return (_isRunning || _isPaused) ? c!.remainingAt(_timers.now) : _phaseSeconds;
  }

  Future<void> _toggle() async {
    final c = _current;
    if (_isRunning) {
      await _timers.pause(c!.id);
    } else if (_isPaused) {
      await _timers.resume(c!.id);
    } else {
      await _timers.start(
        label: _task.title,
        seconds: _phaseSeconds,
        kind: _isWorking ? TimerKind.pomodoroWork : TimerKind.pomodoroBreak,
        taskId: _task.id,
        taskDate: _task.date,
      );
    }
  }

  Future<void> _reset() async {
    final c = _current;
    if (c != null) await _timers.remove(c.id);
  }

  void _showSettingsDialog() async {
    int tempWork = _workMinutes;
    int tempBreak = _breakMinutes;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Configurar Pomodoro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MinutesStepper(
                label: 'Trabajo',
                value: tempWork,
                min: 1,
                max: 90,
                onChanged: (v) => setLocal(() => tempWork = v),
              ),
              const SizedBox(height: 12),
              _MinutesStepper(
                label: 'Descanso',
                value: tempBreak,
                min: 1,
                max: 30,
                onChanged: (v) => setLocal(() => tempBreak = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      widget.onSettingsSaved(tempWork, tempBreak);
      setState(() {
        _workMinutes = tempWork;
        _breakMinutes = tempBreak;
      });
    }
  }

  String get _timeText {
    final remaining = _remainingSeconds;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 1.0;

  Color get _phaseColor => _isWorking ? Colors.deepOrange : Colors.green;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _timers,
      builder: (context, _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final theme = Theme.of(context);
    final totalCompleted = _task.pomodorosCompleted;
    final totalEstimated = _task.estimatedPomodoros;
    final active = _isRunning || _isPaused;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Titulo de la tarea
          Text(
            _task.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _isWorking ? 'Trabajo' : 'Descanso',
            style: TextStyle(color: _phaseColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),

          // Timer circular
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(_phaseColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _timeText,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${_workMinutes}m / ${_breakMinutes}m',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Indicador de pomodoros
          _PomodoroIndicator(completed: totalCompleted, total: totalEstimated),
          const SizedBox(height: 4),
          Text(
            '$totalCompleted / $totalEstimated pomodoros',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.settings_outlined),
                onPressed: active ? null : _showSettingsDialog,
                tooltip: 'Configurar duraciones',
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                label: Text(_isRunning ? 'Pausar' : (_isPaused ? 'Continuar' : 'Iniciar')),
                style: FilledButton.styleFrom(
                  backgroundColor: _phaseColor,
                  minimumSize: const Size(140, 48),
                ),
                onPressed: _toggle,
              ),
              const SizedBox(width: 16),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                onPressed: _current == null ? null : _reset,
                tooltip: 'Reiniciar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinutesStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _MinutesStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        Text('$value min', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
