import 'package:flutter/material.dart';
import 'dart:async';

/// Widget que muestra un avatar animado de Mai con diferentes expresiones ASCII art
/// que cambian para simular que está hablando
class MaiAnimatedAvatar extends StatefulWidget {
  final bool isAnimating; // Si está "hablando" o no
  final double fontSize;

  const MaiAnimatedAvatar({
    super.key,
    this.isAnimating = false,
    this.fontSize = 10,
  });

  @override
  State<MaiAnimatedAvatar> createState() => _MaiAnimatedAvatarState();
}

class _MaiAnimatedAvatarState extends State<MaiAnimatedAvatar> {
  int _currentExpressionIndex = 0;
  Timer? _animationTimer;

  // Diferentes expresiones ASCII art de Mai
  static const List<String> _expressions = [
    // Expresión normal/feliz
    '''
    ˚ ༘♡ ⋆｡˚
   ( ◡‿◡ ♡)
    ╰(*´︶\`*)╯''',

    // Expresión hablando 1
    '''
    ˚ ༘♡ ⋆｡˚
   ( ◡ω◡ ♡)
    ╰(*´︶\`*)╯''',

    // Expresión hablando 2
    '''
    ˚ ༘♡ ⋆｡˚
   ( ◠‿◠ ♡)
    ╰(*´︶\`*)╯''',

    // Expresión pensando
    '''
    ˚ ༘♡ ⋆｡˚
   ( ◕‿◕ ♡)
    ╰(*´︶\`*)╯''',

    // Expresión guiño
    '''
    ˚ ༘♡ ⋆｡˚
   ( ^‿^ ♡)
    ╰(*´︶\`*)╯''',

    // Expresión sonriendo
    '''
    ˚ ༘♡ ⋆｡˚
   ( ◠ᴥ◠ ♡)
    ╰(*´︶\`*)╯''',
  ];

  @override
  void initState() {
    super.initState();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(MaiAnimatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnimating != widget.isAnimating) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _animationTimer?.cancel();

    if (widget.isAnimating) {
      // Cuando está "hablando", cambia de expresión cada 300ms
      _animationTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (timer) {
          if (mounted) {
            setState(() {
              _currentExpressionIndex =
                  (_currentExpressionIndex + 1) % _expressions.length;
            });
          }
        },
      );
    } else {
      // Cuando está en reposo, volver a la expresión normal
      if (mounted) {
        setState(() {
          _currentExpressionIndex = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isAnimating ? Colors.purple : Colors.purple[200]!,
          width: widget.isAnimating ? 3 : 2,
        ),
        // Efecto de brillo cuando está hablando
        boxShadow: widget.isAnimating
            ? [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        _expressions[_currentExpressionIndex],
        style: TextStyle(
          fontSize: widget.fontSize,
          color: Colors.purple[700],
          fontFamily: 'monospace',
          height: 1.0,
        ),
      ),
    );
  }
}
