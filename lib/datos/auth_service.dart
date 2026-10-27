import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión con Supabase. Mai es de un solo usuario: se inicia sesión una vez por
/// dispositivo y la sesión queda guardada (cifrada) hasta cerrarla. Las
/// credenciales ya no van dentro de la app; en `env.json` solo quedan la URL y
/// la publishable key, que son públicas.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService shared = AuthService._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Sin `env.json` la app funciona en modo local (key de Groq propia, sin sync).
  static bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;

  bool _initialized = false;
  StreamSubscription<AuthState>? _sub;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> init() async {
    if (!configured || _initialized) return;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: FlutterAuthClientOptions(localStorage: _SecureSessionStorage()),
    );
    _initialized = true;
    _sub = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  bool get isSignedIn => _initialized && _client.auth.currentSession != null;

  String? get email => _initialized ? _client.auth.currentUser?.email : null;

  /// Lanza [AuthException] si las credenciales no son válidas.
  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Cierra la sesión solo en este dispositivo.
  Future<void> signOut() async {
    if (!_initialized) return;
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  /// Token vigente para llamar a las Edge Functions; null sin sesión.
  Future<String?> accessToken() async {
    if (!isSignedIn) return null;
    var session = _client.auth.currentSession!;
    if (session.isExpired) {
      session = (await _client.auth.refreshSession()).session ?? session;
    }
    return session.accessToken;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Guarda la sesión en el almacén seguro del sistema, como [ApiKeyStore].
/// Si no está disponible (Linux sin libsecret) cae a SharedPreferences.
class _SecureSessionStorage extends LocalStorage {
  static const String _key = 'supabase_session';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() async {
    try {
      return await _secure.read(key: _key);
    } catch (e) {
      debugPrint('Almacén seguro no disponible, usando SharedPreferences: $e');
      return (await SharedPreferences.getInstance()).getString(_key);
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _secure.write(key: _key, value: persistSessionString);
    } catch (e) {
      debugPrint('Almacén seguro no disponible, usando SharedPreferences: $e');
      await (await SharedPreferences.getInstance()).setString(_key, persistSessionString);
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _secure.delete(key: _key);
    } catch (_) {}
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
