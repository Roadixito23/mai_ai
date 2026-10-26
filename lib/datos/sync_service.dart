import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'app_database.dart';
import 'remote_store.dart';
import 'sync_schema.dart';

enum SyncStatus {
  /// Falta configurar Supabase (env.json) o la cuenta propietaria.
  disabled,
  idle,
  syncing,

  /// Sin red o error del servidor: los cambios quedan pendientes y se reintenta.
  failed,
}

/// Espeja SQLite con Supabase. Sin conexión no hace nada y los cambios se
/// acumulan (`dirty = 1`); al volver la red se envían en orden y se baja lo nuevo.
///
/// Conflictos: gana la edición con `updated_at` más reciente, fila por fila.
class SyncService extends ChangeNotifier {
  SyncService({RemoteStore? remote, AppDatabase? db, Connectivity? connectivity})
      : _remote = remote ?? SupabaseRemote(),
        _injected = db,
        _connectivity = connectivity;

  static final SyncService shared = SyncService();

  static const int _pushBatch = 200;
  static const int _pullPage = 500;
  static const Duration _debounce = Duration(seconds: 3);
  static const Duration _periodic = Duration(minutes: 5);

  final RemoteStore _remote;
  final AppDatabase? _injected;
  final Connectivity? _connectivity;

  AppDatabase get _store => _injected ?? AppDatabase.instance;

  final _remoteChanges = StreamController<Set<String>>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _running = false;
  bool _runAgain = false;

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncAt;
  String? _lastError;

  SyncStatus get status => _status;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

  /// Tablas que recibieron cambios de otro dispositivo; las pantallas se recargan con esto.
  Stream<Set<String>> get remoteChanges => _remoteChanges.stream;

  /// Engancha los disparadores: cambios locales, vuelta de la red y un latido periódico.
  void start() {
    if (_subs.isNotEmpty) return;
    _subs.add(_store.localChanges.listen((_) => _scheduleSync()));
    _subs.add((_connectivity ?? Connectivity()).onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _scheduleSync();
    }));
    _periodicTimer = Timer.periodic(_periodic, (_) => sync());
    sync();
  }

  void _scheduleSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, sync);
  }

  Future<void> sync() async {
    if (_running) {
      _runAgain = true; // hubo cambios mientras sincronizaba
      return;
    }
    _running = true;
    _setStatus(SyncStatus.syncing);
    try {
      do {
        _runAgain = false;
        if (!await _remote.prepare()) {
          _lastError = null;
          _setStatus(SyncStatus.disabled);
          return;
        }
        final changed = <String>{};
        for (final table in syncTables) {
          // Primero se baja: si otro dispositivo editó lo mismo más tarde, esa
          // versión reemplaza la local y no se sube una edición vieja encima.
          if (await _pull(table)) changed.add(table.name);
          await _push(table);
        }
        _lastSyncAt = DateTime.now();
        _lastError = null;
        if (changed.isNotEmpty && !_remoteChanges.isClosed) _remoteChanges.add(changed);
      } while (_runAgain);
      _setStatus(SyncStatus.idle);
    } catch (e) {
      debugPrint('Sincronización pendiente: $e');
      _lastError = e.toString();
      _setStatus(SyncStatus.failed);
    } finally {
      _running = false;
    }
  }

  Future<void> _push(SyncTable table) async {
    final db = _store.db;
    while (true) {
      final rows = db.select(
        'SELECT * FROM ${table.name} WHERE dirty = 1 ORDER BY updated_at LIMIT $_pushBatch',
      );
      if (rows.isEmpty) return;

      await _remote.upsert(table.name, rows.map(table.toRemote).toList());

      // Solo se limpia lo que no cambió mientras subía; lo editado sigue pendiente.
      _store.transaction(() {
        for (final r in rows) {
          db.execute(
            'UPDATE ${table.name} SET dirty = 0 WHERE id = ? AND updated_at = ?',
            [r['id'], r['updated_at']],
          );
        }
      });
    }
  }

  /// Baja los cambios del servidor. Devuelve true si cambió algo local.
  Future<bool> _pull(SyncTable table) async {
    final cursorKey = 'cursor_${table.name}';
    var cursor = _store.getState(cursorKey);
    var changed = false;

    while (true) {
      final rows = await _remote.fetchChanges(table.name, since: cursor, limit: _pullPage);
      if (rows.isEmpty) break;

      changed |= _applyRemote(table, rows);

      // `>=` repite la última fila en cada vuelta (varias pueden compartir
      // marca de tiempo); aplicarla de nuevo no hace nada.
      final last = rows.last['server_updated_at'] as String;
      final advanced = last != cursor;
      cursor = last;
      _store.setState(cursorKey, last);
      if (rows.length < _pullPage || !advanced) break;
    }
    return changed;
  }

  bool _applyRemote(SyncTable table, List<Map<String, dynamic>> remoteRows) {
    final db = _store.db;
    final names = table.columns.map((c) => c.name).toList();
    final placeholders = List.filled(names.length, '?').join(', ');
    final updates = names.where((n) => n != 'id').map((n) => '$n = excluded.$n').join(', ');
    final upsert = 'INSERT INTO ${table.name} (${names.join(', ')}, dirty) '
        'VALUES ($placeholders, 0) '
        'ON CONFLICT(id) DO UPDATE SET $updates, dirty = 0';

    var changed = false;
    _store.transaction(() {
      for (final remote in remoteRows) {
        final incoming = table.fromRemote(remote);
        final local = db.select(
          'SELECT updated_at FROM ${table.name} WHERE id = ?',
          [incoming['id']],
        );
        // Gana la edición más reciente; si la local es igual o más nueva, se queda.
        if (local.isNotEmpty &&
            (incoming['updated_at'] as int) <= (local.first['updated_at'] as int)) {
          continue;
        }
        db.execute(upsert, names.map((n) => incoming[n]).toList());
        changed = true;
      }
    });
    return changed;
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _remoteChanges.close();
    super.dispose();
  }
}
