import 'dart:async';
import 'package:flutter/material.dart';
import '../cerebro/memoria_service.dart';
import '../datos/sync_service.dart';
import '../modelos/recuerdo.dart';

/// Lo que Mai recuerda del usuario: se puede revisar, agregar y borrar.
class MemoriasScreen extends StatefulWidget {
  const MemoriasScreen({super.key});

  @override
  State<MemoriasScreen> createState() => _MemoriasScreenState();
}

class _MemoriasScreenState extends State<MemoriasScreen> {
  final MemoriaService _service = MemoriaService();
  final TextEditingController _controller = TextEditingController();
  List<Recuerdo> _recuerdos = [];
  StreamSubscription<Set<String>>? _syncSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Recuerdos guardados desde otro dispositivo.
    _syncSub = SyncService.shared.remoteChanges.listen((tables) {
      if (tables.contains('memories')) _load();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    if (!mounted) return;
    // Los más nuevos arriba.
    setState(() => _recuerdos = _service.listar().reversed.toList());
  }

  void _agregar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    _service.recordar(texto);
    _controller.clear();
    _load();
  }

  void _olvidar(Recuerdo r) {
    _service.olvidar(r.id);
    _load();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recuerdo borrado'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            _service.recordar(r.text);
            _load();
          },
        ),
      ),
    );
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lo que Mai recuerda'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _agregar(),
                    decoration: const InputDecoration(
                      hintText: 'Agregar algo para que Mai lo recuerde…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar',
                  onPressed: _agregar,
                ),
              ],
            ),
          ),
          Expanded(
            child: _recuerdos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Mai todavía no recuerda nada de ti.\n'
                        'Dile en el chat, por ejemplo: "recuerda que mi cumpleaños es el 3 de mayo".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _recuerdos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = _recuerdos[i];
                      return ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(r.text),
                        subtitle: Text(_fecha(r.createdAt)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Olvidar',
                          onPressed: () => _olvidar(r),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
