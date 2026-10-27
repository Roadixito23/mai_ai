import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/sistema/lanzador.dart';

void main() {
  final lanzador = Lanzador.shared;
  late List<PeticionMai> recibidas;
  void destino(PeticionMai p) => recibidas.add(p);

  setUp(() => recibidas = []);
  tearDown(() => lanzador.dejarDeEscuchar(destino));

  test('lo que llega antes de que haya chat queda en cola y se entrega en orden', () {
    lanzador.pedir(const Compartido('resume esto'));
    lanzador.pedir(const Escuchar());
    expect(recibidas, isEmpty);

    lanzador.escuchar(destino);
    expect(recibidas, hasLength(2));
    expect((recibidas.first as Compartido).texto, 'resume esto');
    expect(recibidas.last, isA<Escuchar>());
  });

  test('con el chat escuchando, entrega al momento', () {
    lanzador.escuchar(destino);
    lanzador.pedir(const Escuchar());
    expect(recibidas.single, isA<Escuchar>());
  });

  test('al dejar de escuchar vuelve a encolar', () {
    lanzador.escuchar(destino);
    lanzador.dejarDeEscuchar(destino);
    lanzador.pedir(const Escuchar());
    expect(recibidas, isEmpty);

    lanzador.escuchar(destino);
    expect(recibidas.single, isA<Escuchar>());
  });
}
