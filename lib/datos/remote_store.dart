import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

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

/// Supabase con la sesión del dueño ([AuthService]). Sin sesión no sincroniza:
/// los cambios quedan pendientes hasta iniciar sesión. Las reglas RLS siguen activas.
class SupabaseRemote implements RemoteStore {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<bool> prepare() async {
    if (!AuthService.configured) return false;
    await AuthService.shared.init();
    return AuthService.shared.isSignedIn;
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
