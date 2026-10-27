import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mai_ai/cerebro/ai_exceptions.dart';
import 'package:mai_ai/cerebro/ai_service.dart';
import 'package:mai_ai/cerebro/api_key_store.dart';
import 'package:mai_ai/cerebro/herramientas.dart';
import 'package:mai_ai/cerebro/memoria_service.dart';
import 'package:mai_ai/cerebro/task_service.dart';
import 'package:mai_ai/datos/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mai_ai/modelos/chat_message.dart';

ChatMessage user(String t) => ChatMessage.user(text: t);
ChatMessage mai(String t) => ChatMessage.assistant(text: t);

String textOf(Map<String, String> m) => m['content']!;

void main() {
  group('AIService.buildHistory', () {
    test('mapea roles user/model en orden', () {
      final h = AIService.buildHistory([user('hola'), mai('hey'), user('qué tal')]);
      expect(h.map((m) => m['role']), ['user', 'assistant', 'user']);
      expect(h.map(textOf), ['hola', 'hey', 'qué tal']);
    });

    test('descarta errores y mensajes vacíos', () {
      final h = AIService.buildHistory([
        user('hola'),
        ChatMessage.error(errorMessage: 'falló'),
        mai(''),
        user('otra vez'),
      ]);
      expect(h.map(textOf), ['hola', 'otra vez']);
    });

    test('se queda con los más recientes', () {
      final msgs = [for (var i = 0; i < 10; i++) i.isEven ? user('u$i') : mai('m$i')];
      final h = AIService.buildHistory(msgs, maxMessages: 4);
      expect(h.map(textOf), ['u6', 'm7', 'u8', 'm9']);
    });

    test('nunca empieza con un mensaje del modelo', () {
      final msgs = [user('u0'), mai('m1'), user('u2'), mai('m3'), user('u4')];
      final h = AIService.buildHistory(msgs, maxMessages: 4); // corta en m1
      expect(h.first['role'], 'user');
      expect(h.map(textOf), ['u2', 'm3', 'u4']);
    });

    test('lista vacía da historial vacío', () {
      expect(AIService.buildHistory([]), isEmpty);
    });
  });

  group('AIService con herramientas', () {
    late AppDatabase db;
    late TaskService tasks;
    late List<Map<String, dynamic>> requests;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      tasks = TaskService(db: db);
      requests = [];
    });
    tearDown(() => db.dispose());

    String sse(List<Map<String, dynamic>> deltas) => [
          for (final d in deltas)
            'data: ${jsonEncode({
                  'choices': [
                    {'delta': d}
                  ]
                })}\n\n',
          'data: [DONE]\n\n',
        ].join();

    /// Responde en orden con cada cuerpo SSE de [responses].
    AIService service(List<String> responses) {
      var i = 0;
      final client = MockClient.streaming((request, body) async {
        requests.add(jsonDecode(await body.bytesToString()) as Map<String, dynamic>);
        return http.StreamedResponse(Stream.value(utf8.encode(responses[i++])), 200);
      });
      return AIService(
        keyStore: _FixedKey(),
        clientFactory: () => client,
        herramientas: Herramientas(tasks: tasks, memoria: MemoriaService(db: db), now: () => DateTime(2026, 3, 4)),
      );
    }

    test('ejecuta la herramienta, devuelve el resultado y sigue con el texto', () async {
      final ai = service([
        sse([
          {
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_1',
                'function': {'name': 'crear_tarea', 'arguments': '{"titulo":'},
              }
            ]
          },
          {
            'tool_calls': [
              {
                'index': 0,
                'function': {'arguments': ' "Comprar pan"}'},
              }
            ]
          },
        ]),
        sse([
          {'content': 'Listo, '},
          {'content': 'agregada.'},
        ]),
      ]);

      final acciones = <String>[];
      final text = await ai
          .sendMessageStream([user('agrega comprar pan')], onAction: acciones.add)
          .join();

      expect(text, 'Listo, agregada.');
      expect(acciones, ['Tarea creada: Comprar pan (2026-03-04)']);
      expect((await tasks.getTasksForDate(DateTime(2026, 3, 4))).single.title, 'Comprar pan');

      expect(requests, hasLength(2));
      expect(requests.first['tools'], isNotEmpty);
      final segunda = requests[1]['messages'] as List;
      expect(segunda[segunda.length - 2]['tool_calls'][0]['id'], 'call_1');
      expect(segunda.last['role'], 'tool');
      expect(segunda.last['tool_call_id'], 'call_1');
    });

    test('si el modelo no admite herramientas, reintenta sin ellas', () async {
      var i = 0;
      final client = MockClient.streaming((request, body) async {
        requests.add(jsonDecode(await body.bytesToString()) as Map<String, dynamic>);
        if (i++ == 0) {
          final error = jsonEncode({
            'error': {'message': '`tool calling` is not supported with this model'}
          });
          return http.StreamedResponse(Stream.value(utf8.encode(error)), 400);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse([
            {'content': 'hola'}
          ]))),
          200,
        );
      });
      final ai = AIService(
        keyStore: _FixedKey(),
        clientFactory: () => client,
        herramientas: Herramientas(tasks: tasks, memoria: MemoriaService(db: db)),
      );

      expect(await ai.sendMessageStream([user('hey')]).join(), 'hola');
      expect(requests, hasLength(2));
      expect(requests.first.containsKey('tools'), isTrue);
      expect(requests.last.containsKey('tools'), isFalse);
    });

    test('por el proxy usa el endpoint dado y un 401 es sesión expirada', () async {
      final seen = <http.BaseRequest>[];
      final client = MockClient.streaming((request, body) async {
        seen.add(request);
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 401);
      });
      final ai = AIService(
        clientFactory: () => client,
        endpoint: () async => const AiEndpoint(
          'https://x.supabase.co/functions/v1/groq',
          {'Authorization': 'Bearer jwt'},
          viaProxy: true,
        ),
      );

      await expectLater(
        ai.sendMessageStream([user('hey')]).join(),
        throwsA(isA<AIException>().having((e) => e.kind, 'kind', AIErrorKind.sessionExpired)),
      );
      expect(seen.single.url.toString(),
          'https://x.supabase.co/functions/v1/groq/chat/completions');
      expect(seen.single.headers['Authorization'], 'Bearer jwt');
    });

    test('transcribe envía el audio como multipart a Whisper', () async {
      final dir = await Directory.systemTemp.createTemp('mai_test');
      final audio = File('${dir.path}/voz.wav')..writeAsBytesSync([1, 2, 3, 4]);
      late http.BaseRequest seen;
      late String body;
      final client = MockClient.streaming((request, stream) async {
        seen = request;
        body = latin1.decode(await stream.toBytes());
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'text': ' pon un timer de diez minutos '}))),
          200,
        );
      });
      final ai = AIService(
        clientFactory: () => client,
        endpoint: () async => const AiEndpoint('https://proxy/groq', {'Authorization': 'Bearer jwt'}),
      );

      expect(await ai.transcribe(audio.path), 'pon un timer de diez minutos');
      expect(seen.url.toString(), 'https://proxy/groq/audio/transcriptions');
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(body, contains(AIService.transcriptionModel));
      expect(body, contains('filename="voz.wav"'));
      await dir.delete(recursive: true);
    });

    test('sin tool calls hace una sola petición', () async {
      final ai = service([
        sse([
          {'content': 'hola'}
        ])
      ]);
      expect(await ai.sendMessageStream([user('hey')]).join(), 'hola');
      expect(requests, hasLength(1));
    });
  });
}

class _FixedKey extends ApiKeyStore {
  @override
  Future<String> read() async => 'test-key';
}
