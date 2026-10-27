import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la API key de Groq que introduce cada usuario.
///
/// Usa el almacén seguro del sistema (Keystore en Android, DPAPI en Windows,
/// libsecret en Linux). Si el almacén seguro no está disponible (por ejemplo,
/// Linux sin libsecret) cae a SharedPreferences para que la app siga siendo usable.
class ApiKeyStore {
  ApiKeyStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  static const String _key = 'google_api_key';

  final FlutterSecureStorage _secure;
  String? _cached;

  Future<String> read() async {
    if (_cached != null) return _cached!;
    String? value;
    try {
      value = await _secure.read(key: _key);
    } catch (e) {
      debugPrint('Almacén seguro no disponible, usando SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key);
    }
    _cached = (value ?? '').trim();
    return _cached!;
  }

  Future<bool> hasKey() async => (await read()).isNotEmpty;

  Future<void> save(String apiKey) async {
    final value = apiKey.trim();
    _cached = value;
    try {
      await _secure.write(key: _key, value: value);
    } catch (e) {
      debugPrint('Almacén seguro no disponible, usando SharedPreferences: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value);
    }
  }

  Future<void> clear() async {
    _cached = '';
    try {
      await _secure.delete(key: _key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
