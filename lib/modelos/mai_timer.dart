enum TimerKind { custom, pomodoroWork, pomodoroBreak }

enum TimerStatus { running, paused, done }

/// Temporizador persistente. Mientras corre guarda la hora absoluta de fin
/// (`endsAt`), así sobrevive a cerrar la app y no depende de contar segundos.
class MaiTimer {
  final String id;
  final String label;
  final TimerKind kind;
  final int durationSeconds;
  final TimerStatus status;

  /// Solo cuando `status == running`.
  final DateTime? endsAt;

  /// Solo cuando `status == paused`.
  final int? remainingSeconds;

  /// Tarea a la que pertenece un pomodoro.
  final String? taskId;
  final DateTime? taskDate;

  /// Un pomodoro terminado ya se sumó a su tarea.
  final bool handled;
  final DateTime updatedAt;

  const MaiTimer({
    required this.id,
    required this.label,
    required this.kind,
    required this.durationSeconds,
    required this.status,
    required this.updatedAt,
    this.endsAt,
    this.remainingSeconds,
    this.taskId,
    this.taskDate,
    this.handled = false,
  });

  bool get isPomodoro => kind != TimerKind.custom;

  /// Segundos que faltan en el instante [now].
  int remainingAt(DateTime now) {
    switch (status) {
      case TimerStatus.running:
        final ms = endsAt!.difference(now).inMilliseconds;
        return ms <= 0 ? 0 : (ms / 1000).ceil();
      case TimerStatus.paused:
        return remainingSeconds ?? durationSeconds;
      case TimerStatus.done:
        return 0;
    }
  }

  bool isDueAt(DateTime now) =>
      status == TimerStatus.running && !endsAt!.isAfter(now);

  MaiTimer copyWith({
    TimerStatus? status,
    DateTime? endsAt,
    int? remainingSeconds,
    bool? handled,
    required DateTime updatedAt,
    bool clearEndsAt = false,
    bool clearRemaining = false,
  }) =>
      MaiTimer(
        id: id,
        label: label,
        kind: kind,
        durationSeconds: durationSeconds,
        status: status ?? this.status,
        endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
        remainingSeconds:
            clearRemaining ? null : (remainingSeconds ?? this.remainingSeconds),
        taskId: taskId,
        taskDate: taskDate,
        handled: handled ?? this.handled,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kind': kind.name,
        'durationSeconds': durationSeconds,
        'status': status.name,
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'remainingSeconds': remainingSeconds,
        'taskId': taskId,
        'taskDate': taskDate?.toIso8601String(),
        'handled': handled,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory MaiTimer.fromJson(Map<String, dynamic> json) => MaiTimer(
        id: json['id'] as String,
        label: json['label'] as String,
        kind: TimerKind.values.byName(json['kind'] as String),
        durationSeconds: json['durationSeconds'] as int,
        status: TimerStatus.values.byName(json['status'] as String),
        endsAt: json['endsAt'] == null
            ? null
            : DateTime.parse(json['endsAt'] as String).toLocal(),
        remainingSeconds: json['remainingSeconds'] as int?,
        taskId: json['taskId'] as String?,
        taskDate: json['taskDate'] == null
            ? null
            : DateTime.parse(json['taskDate'] as String),
        handled: json['handled'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}
