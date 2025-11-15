import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modelos/chat_message.dart';
import 'mai_animated_avatar.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAnimating; // Para animar el avatar cuando Mai está hablando

  const MessageBubble({
    super.key,
    required this.message,
    this.isAnimating = false,
  });

  void _copiarMensaje(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Mensaje copiado al portapapeles'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar de Mai con ASCII art animado
          if (!message.isUser) ...[
            MaiAnimatedAvatar(
              isAnimating: isAnimating,
              fontSize: 10,
            ),
            const SizedBox(width: 12),
          ],

          // Mensaje
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Colors.blue[600]
                        : Colors.purple[50],
                    borderRadius: BorderRadius.circular(16),
                    border: message.isUser
                        ? null
                        : Border.all(color: Colors.purple[200]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Botón de copiar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copiarMensaje(context, message.text),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text(
                        'Copiar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Avatar del usuario
          if (message.isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Colors.blue[700],
              radius: 20,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ],
        ],
      ),
    );
  }
}
