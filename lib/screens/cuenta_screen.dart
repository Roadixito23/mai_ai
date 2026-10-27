import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../datos/auth_service.dart';

/// Cambiar el usuario y la contraseña de Mai. Pide la contraseña actual.
class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  final _usuario = TextEditingController(text: AuthService.shared.username);
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _obscure = true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  /// Null si todo está bien; si no, qué corregir.
  String? _validar() {
    if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(_usuario.text.trim())) {
      return 'El usuario debe tener de 3 a 32 caracteres: letras, números, . _ -';
    }
    if (_actual.text.isEmpty) return 'Escribe tu contraseña actual.';
    // Vacía = se conserva la contraseña actual.
    final nueva = _nueva.text.isEmpty ? _actual.text : _nueva.text;
    if (nueva.length < 6) return 'La contraseña nueva debe tener al menos 6 caracteres.';
    if (_nueva.text != _repetir.text) return 'Las contraseñas nuevas no coinciden.';
    return null;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    final problema = _validar();
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await AuthService.shared.changeCredentials(
        currentPassword: _actual.text,
        newUsername: _usuario.text.trim(),
        newPassword: _nueva.text.isEmpty ? _actual.text : _nueva.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listo. Usa estos datos en tus otros dispositivos.')),
      );
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      setState(() => _error = e.message.contains('users_email')
          ? 'Ese usuario ya existe.'
          : e.message);
    } catch (_) {
      setState(() => _error = 'No pude conectarme. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  InputDecoration _decoracion(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: suffix);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Usuario y contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _usuario,
                  autocorrect: false,
                  decoration: _decoracion('Usuario'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _actual,
                  obscureText: _obscure,
                  decoration: _decoracion(
                    'Contraseña actual',
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nueva,
                  obscureText: _obscure,
                  decoration: _decoracion('Contraseña nueva (opcional)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _repetir,
                  obscureText: _obscure,
                  onSubmitted: (_) => _guardar(),
                  decoration: _decoracion('Repetir contraseña nueva'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
