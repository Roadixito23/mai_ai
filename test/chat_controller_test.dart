import 'package:flutter_test/flutter_test.dart';
import 'package:mai_ai/cerebro/ai_exceptions.dart';
import 'package:mai_ai/cerebro/ai_service.dart';
import 'package:mai_ai/cerebro/chat_controller.dart';
import 'package:mai_ai/cerebro/persistencia_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:mai_ai/modelos/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBackend implements ChatBackend {
  FakeBackend(this.run);
  final Stream<String> Function(List<ChatMessage>) run;
  List<ChatMessage>? received;

  @override
  Stream<String> sendMessageStream(
    List<ChatMessage> messages, {
    void Function(String resumen)? onAction,
  }) {
    received = messages;
    return run(messages);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() {
    SharedPreferences.setMockInitialValues({}); // el modelo elegido vive en prefs
    db = AppDatabase.memory();
  });
  tearDown(() => db.dispose());

  ChatController newChat(ChatBackend backend) =>
      ChatController(backend: backend, storage: PersistenciaService(db: db));

  test('acumula el streaming en un solo mensaje de Mai y lo guarda', () async {
    final backend = FakeBackend((_) => Stream.fromIterable(['Hola', ', ', 'mundo']));
    final chat = newChat(backend);
    await chat.init();

    await chat.send('  hey  ');

    expect(chat.messages.map((m) => m.text), ['hey', 'Hola, mundo']);
    expect(chat.messages.last.isUser, isFalse);
    expect(chat.isLoading, isFalse);
    // El placeholder vacío de la respuesta no viaja como contexto.
    expect(backend.received!.map((m) => m.text), ['hey']);

    final saved = await PersistenciaService(db: db).cargarMensajes();
    expect(saved.map((m) => m.text), ['hey', 'Hola, mundo']);
  });

  test('un error se muestra pero no se guarda ni se reenvía como contexto', () async {
    var fail = true;
    final backend = FakeBackend((_) async* {
      if (fail) throw const AIException(AIErrorKind.network);
      yield 'ya sí';
    });
    final chat = newChat(backend);
    await chat.init();

    await chat.send('uno');
    expect(chat.messages.last.isError, isTrue);
    expect(chat.lastError?.kind, AIErrorKind.network);
    expect((await PersistenciaService(db: db).cargarMensajes()).map((m) => m.text), ['uno']);

    fail = false;
    await chat.send('dos');
    expect(chat.lastError, isNull);
    expect(chat.messages.last.text, 'ya sí');
    expect(backend.received!.where((m) => m.isError), isEmpty);
  });

  test('una API key faltante queda marcada para pedirla', () async {
    final backend = FakeBackend((_) => Stream.error(const AIException(AIErrorKind.missingApiKey)));
    final chat = newChat(backend);
    await chat.init();

    await chat.send('hola');

    expect(chat.lastError!.needsApiKey, isTrue);
  });

  test('ignora mensajes vacíos', () async {
    final backend = FakeBackend((_) => Stream.value('ok'));
    final chat = newChat(backend);
    await chat.init();

    await chat.send('   ');
    expect(chat.messages, isEmpty);
  });

  test('clear borra memoria y disco', () async {
    final chat = newChat(FakeBackend((_) => Stream.value('ok')));
    await chat.init();
    await chat.send('hola');

    await chat.clear();

    expect(chat.messages, isEmpty);
    expect(await PersistenciaService(db: db).cargarMensajes(), isEmpty);
  });
}
