import 'package:supabase_flutter/supabase_flutter.dart';

/// Lo que la sincronización necesita del servidor. Permite probarla sin red.
abstract interface class RemoteStore {
  /// Deja la conexión lista (sesión iniciada). false si no hay configuración.
  Future<bool> prepare();

  Future<void> upsert(String table, List<Map<String, dynamic>> rows);

  /// Filas con `server_updated_at >= since`, de la más antigua a la más nueva.
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    String? since,
    required int limit,
  });
}

/// Supabase con una cuenta propietaria fija: la app es de un solo usuario, así
/// que no hay pantalla de login; entra sola con las credenciales de `env.json`
/// (`--dart-define-from-file=env.json`). Las reglas RLS siguen activas.
class SupabaseRemote implements RemoteStore {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String ownerEmail = String.fromEnvironment('OWNER_EMAIL');
  static const String ownerPassword = String.fromEnvironment('OWNER_PASSWORD');

  static bool get configured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      ownerEmail.isNotEmpty &&
      ownerPassword.isNotEmpty;

  bool _initialized = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<bool> prepare() async {
    if (!configured) return false;
    if (!_initialized) {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _initialized = true;
    }
    if (_client.auth.currentSession == null) {
      await _client.auth.signInWithPassword(email: ownerEmail, password: ownerPassword);
    }
    return true;
  }

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from(table).upsert(rows, onConflict: 'id');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    String? since,
    required int limit,
  }) async {
    var query = _client.from(table).select();
    if (since != null) query = query.gte('server_updated_at', since);
    final rows = await query.order('server_updated_at', ascending: true).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }
}
