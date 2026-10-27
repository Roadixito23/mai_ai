import 'package:uuid/uuid.dart';
import '../datos/app_database.dart';
import '../modelos/recuerdo.dart';

/// Memoria personal de Mai, guardada en SQLite y sincronizada entre dispositivos.
class MemoriaService {
  MemoriaService({AppDatabase? db}) : _injected = db;

  /// Recuerdos que viajan en cada mensaje; con más, Mai usa `buscar_recuerdos`.
  static const int maxEnPrompt = 60;

  final AppDatabase? _injected;
  AppDatabase get _store => _injected ?? AppDatabase.instance;

  Recuerdo _fromRow(Map<String, Object?> r) => Recuerdo(
        id: r['id'] as String,
        text: r['text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int, isUtc: true)
            .toLocal(),
      );

  /// Del más antiguo al más nuevo.
  List<Recuerdo> listar() => _store.db
      .select('SELECT * FROM memories WHERE deleted_at IS NULL ORDER BY created_at, rowid')
      .map(_fromRow)
      .toList();

  /// Los más recientes, para el system prompt.
  List<Recuerdo> paraPrompt() {
    final todos = listar();
    return todos.length <= maxEnPrompt ? todos : todos.sublist(todos.length - maxEnPrompt);
  }

  /// Guarda [texto]. Si ya existe igual (sin distinguir mayúsculas), no lo duplica.
  Recuerdo recordar(String texto) {
    final clean = texto.trim();
    if (clean.isEmpty) throw ArgumentError('El recuerdo está vacío');
    for (final r in listar()) {
      if (r.text.toLowerCase() == clean.toLowerCase()) return r;
    }
    final now = AppDatabase.nowMs();
    final recuerdo = Recuerdo(
      id: const Uuid().v4(),
      text: clean,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true).toLocal(),
    );
    _store.db.execute(
      'INSERT INTO memories (id, text, created_at, updated_at, dirty) VALUES (?, ?, ?, ?, 1)',
      [recuerdo.id, clean, now, now],
    );
    _store.notifyLocalChange();
    return recuerdo;
  }

  /// Recuerdos cuyo texto contiene todas las palabras de [consulta].
  List<Recuerdo> buscar(String consulta) {
    final palabras = consulta.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return listar().where((r) {
      final t = r.text.toLowerCase();
      return palabras.every(t.contains);
    }).toList();
  }

  /// Borrado lógico: la fila queda para avisar a los demás dispositivos.
  void olvidar(String id) {
    final now = AppDatabase.nowMs();
    _store.db.execute(
      'UPDATE memories SET deleted_at = ?, updated_at = ?, dirty = 1 '
      'WHERE id = ? AND deleted_at IS NULL',
      [now, now, id],
    );
    _store.notifyLocalChange();
  }
}
