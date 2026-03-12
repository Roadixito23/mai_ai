class Task {
  final String id;
  String title;
  final DateTime date;
  bool isCompleted;
  int pomodorosCompleted;
  int estimatedPomodoros;

  Task({
    required this.id,
    required this.title,
    required this.date,
    this.isCompleted = false,
    this.pomodorosCompleted = 0,
    this.estimatedPomodoros = 1,
  });

  factory Task.create({
    required String title,
    required DateTime date,
    int estimatedPomodoros = 1,
  }) {
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      date: DateTime(date.year, date.month, date.day),
      estimatedPomodoros: estimatedPomodoros,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'isCompleted': isCompleted,
        'pomodorosCompleted': pomodorosCompleted,
        'estimatedPomodoros': estimatedPomodoros,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        isCompleted: json['isCompleted'] as bool? ?? false,
        pomodorosCompleted: json['pomodorosCompleted'] as int? ?? 0,
        estimatedPomodoros: json['estimatedPomodoros'] as int? ?? 1,
      );

  Task copyWith({
    String? title,
    bool? isCompleted,
    int? pomodorosCompleted,
    int? estimatedPomodoros,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        date: date,
        isCompleted: isCompleted ?? this.isCompleted,
        pomodorosCompleted: pomodorosCompleted ?? this.pomodorosCompleted,
        estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      );
}
