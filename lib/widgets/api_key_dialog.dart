import 'package:flutter/material.dart';
import '../cerebro/api_key_store.dart';

/// Pide la API key de Gemini y la guarda. Devuelve true si se guardó una key.
class ApiKeyDialog extends StatefulWidget {
  final ApiKeyStore store;

  const ApiKeyDialog({super.key, required this.store});

  static Future<bool> show(BuildContext context, ApiKeyStore store) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ApiKeyDialog(store: store),
    );
    return saved ?? false;
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _hasExisting = false;

  @override
  void initState() {
    super.initState();
    widget.store.hasKey().then((has) {
      if (mounted) setState(() => _hasExisting = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await widget.store.save(value);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    await widget.store.clear();
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API key de Gemini'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consíguela gratis en aistudio.google.com/app/apikey. '
            'Se guarda cifrada en este dispositivo y solo se envía a Google.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: _hasExisting ? 'Nueva API key (ya hay una guardada)' : 'API key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_hasExisting)
          TextButton(
            onPressed: _remove,
            child: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
