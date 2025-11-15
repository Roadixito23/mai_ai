import 'package:flutter/material.dart';
import '../cerebro/config.dart';

class TextComposer extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmit;
  final bool isLoading;

  const TextComposer({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  int _currentLength = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateLength);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLength);
    super.dispose();
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
                child: TextField(
                  controller: widget.controller,
                  onSubmitted: widget.isLoading ? null : widget.onSubmit,
                  enabled: !widget.isLoading,
                  maxLength: Config.maxInputCharacters,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: widget.isLoading || isAtLimit
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
