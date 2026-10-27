import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cerebro/config.dart';

class TextComposer extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmit;
  final bool isLoading;

  /// Entrada de voz: null oculta el micrófono.
  final VoidCallback? onMicPressed;
  final bool isRecording;

  const TextComposer({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.isLoading,
    this.onMicPressed,
    this.isRecording = false,
  });

  @override
  State<TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  int _currentLength = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLength);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLength);
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !widget.isLoading) {
      final text = widget.controller.text;
      if (text.trim().isNotEmpty) {
        widget.onSubmit(text);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _updateLength() {
    setState(() {
      _currentLength = widget.controller.text.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNearLimit =
        _currentLength > (Config.maxInputCharacters * 0.8).round();
    final isAtLimit = _currentLength >= Config.maxInputCharacters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentLength > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$_currentLength/${Config.maxInputCharacters}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAtLimit
                          ? Colors.red
                          : isNearLimit
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: widget.controller,
                    enabled: !widget.isLoading && !widget.isRecording,
                    maxLength: Config.maxInputCharacters,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: widget.isRecording
                          ? 'Escuchando… toca el botón rojo para enviar'
                          : 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      counterText: '', // Ocultar el contador predeterminado
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onMicPressed != null)
                IconButton(
                  icon: Icon(widget.isRecording ? Icons.stop_circle : Icons.mic),
                  tooltip: widget.isRecording ? 'Enviar audio' : 'Hablarle a Mai',
                  onPressed: widget.isLoading ? null : widget.onMicPressed,
                  color: widget.isRecording ? Colors.red : Colors.blue,
                  iconSize: 28,
                ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: widget.isLoading || widget.isRecording || isAtLimit
                    ? null
                    : () => widget.onSubmit(widget.controller.text),
                color: Colors.blue,
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
