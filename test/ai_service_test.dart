import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mai_ai/cerebro/ai_service.dart';
import 'package:mai_ai/modelos/chat_message.dart';

ChatMessage user(String t) => ChatMessage.user(text: t);
ChatMessage mai(String t) => ChatMessage.assistant(text: t);

String textOf(Content c) => (c.parts.single as TextPart).text;

void main() {
  group('AIService.buildHistory', () {
    test('mapea roles user/model en orden', () {
      final h = AIService.buildHistory([user('hola'), mai('hey'), user('qué tal')]);
      expect(h.map((c) => c.role), ['user', 'model', 'user']);
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
      expect(h.first.role, 'user');
      expect(h.map(textOf), ['u2', 'm3', 'u4']);
    });

    test('lista vacía da historial vacío', () {
      expect(AIService.buildHistory([]), isEmpty);
    });
  });
}
