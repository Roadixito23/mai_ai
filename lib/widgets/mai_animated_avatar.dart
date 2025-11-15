import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Widget que muestra un avatar animado de Mai
/// Muestra una "M" cuando está en reposo y un radar circular cuando está generando
class MaiAnimatedAvatar extends StatefulWidget {
  final bool isAnimating; // Si está generando mensaje
  final double size;

  const MaiAnimatedAvatar({
    super.key,
    this.isAnimating = false,
    this.size = 60,
  });

  @override
  State<MaiAnimatedAvatar> createState() => _MaiAnimatedAvatarState();
}

class _MaiAnimatedAvatarState extends State<MaiAnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
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
    if (widget.isAnimating) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isAnimating ? Colors.purple : Colors.purple[200]!,
          width: widget.isAnimating ? 3 : 2,
        ),
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
      child: widget.isAnimating
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarPainter(
                    animation: _controller.value,
                    color: Colors.purple,
                  ),
                );
              },
            )
          : Center(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: widget.size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
            ),
    );
  }
}

/// Painter para el efecto de radar circular
class RadarPainter extends CustomPainter {
  final double animation;
  final Color color;

  RadarPainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 * 0.8;

    // Dibujar 3 ondas expansivas con diferentes fases
    for (int i = 0; i < 3; i++) {
      final phaseOffset = i * 0.33;
      final waveAnimation = (animation + phaseOffset) % 1.0;
      final radius = maxRadius * waveAnimation;
      final opacity = 1.0 - waveAnimation;

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }

    // Dibujar círculo central
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius * 0.15, centerPaint);

    // Dibujar línea de radar rotando
    final angle = animation * 2 * math.pi;
    final radarEnd = Offset(
      center.dx + maxRadius * math.cos(angle),
      center.dy + maxRadius * math.sin(angle),
    );

    final radarPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(center, radarEnd, radarPaint);

    // Efecto de gradiente en la línea del radar
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: radarEnd, radius: maxRadius * 0.3))
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      -math.pi / 6,
      math.pi / 3,
      true,
      gradientPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
