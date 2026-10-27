import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Algo que pidió el sistema operativo: el atajo global, la bandeja, el tile
/// de ajustes rápidos o "Compartir" en Android.
sealed class PeticionMai {
  const PeticionMai();
}

/// Mostrar a Mai y empezar a escuchar.
class Escuchar extends PeticionMai {
  const Escuchar();
}

/// Texto compartido desde otra app.
class Compartido extends PeticionMai {
  const Compartido(this.texto);
  final String texto;
}

/// Reparte las peticiones al chat. Si llegan antes de que el chat exista
/// (arranque en frío desde el tile o desde Compartir, o con la pantalla de
/// login delante) quedan en cola hasta que alguien escuche.
class Lanzador {
  Lanzador._();

  static final Lanzador shared = Lanzador._();

  static const MethodChannel _android = MethodChannel('mai/lanzador');

  final List<PeticionMai> _pendientes = [];
  void Function(PeticionMai)? _destino;

  void pedir(PeticionMai peticion) {
    final destino = _destino;
    if (destino != null) {
      destino(peticion);
    } else {
      _pendientes.add(peticion);
    }
  }

  /// El chat se suscribe al aparecer; recibe primero lo que estaba en cola.
  void escuchar(void Function(PeticionMai) destino) {
    _destino = destino;
    final cola = List.of(_pendientes);
    _pendientes.clear();
    cola.forEach(destino);
  }

  void dejarDeEscuchar(void Function(PeticionMai) destino) {
    // `==` y no `identical`: cada tear-off de un método es un objeto nuevo.
    if (_destino == destino) _destino = null;
  }

  /// En Android, la actividad nativa avisa por un canal: al arrancar se piden
  /// las peticiones con que se abrió la app y luego llegan las nuevas.
  Future<void> initAndroid() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _android.setMethodCallHandler((call) async {
      final p = _desdeNativo(call.arguments);
      if (p != null) pedir(p);
    });
    try {
      final inicial = await _android.invokeMethod<Object?>('peticionInicial');
      final p = _desdeNativo(inicial);
      if (p != null) pedir(p);
    } on PlatformException catch (e) {
      debugPrint('Lanzador de Android no disponible: $e');
    }
  }

  static PeticionMai? _desdeNativo(Object? args) {
    if (args is! Map) return null;
    switch (args['tipo']) {
      case 'escuchar':
        return const Escuchar();
      case 'compartir':
        final texto = (args['texto'] as String?)?.trim() ?? '';
        return texto.isEmpty ? null : Compartido(texto);
    }
    return null;
  }
}
