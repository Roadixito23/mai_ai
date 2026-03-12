import 'dart:math' as math;
import 'package:flutter/material.dart';

enum MaiFaceState { normal, winkLeft, winkRight, happy, sad, angry }

class MaiFacePainter extends CustomPainter {
  final MaiFaceState state;
  final Color faceColor;
  final Color accentColor;

  const MaiFacePainter({
    required this.state,
    required this.faceColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final faceRadius = math.min(size.width, size.height) * 0.38;

    _drawFace(canvas, center, faceRadius);
    _drawCheeks(canvas, center, faceRadius);
    if (state == MaiFaceState.angry) {
      _drawEyebrows(canvas, center, faceRadius);
    }
    _drawEyes(canvas, center, faceRadius);
    _drawMouth(canvas, center, faceRadius);
  }

  void _drawFace(Canvas canvas, Offset center, double faceRadius) {
    final rect = Rect.fromCenter(
      center: center,
      width: faceRadius * 2,
      height: faceRadius * 2.1,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawCheeks(Canvas canvas, Offset center, double faceRadius) {
    final paint = Paint()
      ..color = const Color(0xFFFFB5C8).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final cheekRadius = faceRadius * 0.21;
    final cheekY = center.dy + faceRadius * 0.12;
    canvas.drawCircle(Offset(center.dx - faceRadius * 0.46, cheekY), cheekRadius, paint);
    canvas.drawCircle(Offset(center.dx + faceRadius * 0.46, cheekY), cheekRadius, paint);
  }

  void _drawEyebrows(Canvas canvas, Offset center, double faceRadius) {
    final paint = Paint()
      ..color = const Color(0xFF3D2B1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceRadius * 0.07
      ..strokeCap = StrokeCap.round;
    final eyeY = center.dy - faceRadius * 0.08;

    // Left brow angled down toward center
    final leftBrow = Path()
      ..moveTo(center.dx - faceRadius * 0.46, eyeY - faceRadius * 0.27)
      ..lineTo(center.dx - faceRadius * 0.12, eyeY - faceRadius * 0.18);
    canvas.drawPath(leftBrow, paint);

    // Right brow angled down toward center
    final rightBrow = Path()
      ..moveTo(center.dx + faceRadius * 0.12, eyeY - faceRadius * 0.18)
      ..lineTo(center.dx + faceRadius * 0.46, eyeY - faceRadius * 0.27);
    canvas.drawPath(rightBrow, paint);
  }

  void _drawEyes(Canvas canvas, Offset center, double faceRadius) {
    final leftCenter = Offset(center.dx - faceRadius * 0.28, center.dy - faceRadius * 0.08);
    final rightCenter = Offset(center.dx + faceRadius * 0.28, center.dy - faceRadius * 0.08);
    _drawSingleEye(canvas, leftCenter, faceRadius, isLeft: true);
    _drawSingleEye(canvas, rightCenter, faceRadius, isLeft: false);
  }

  void _drawSingleEye(Canvas canvas, Offset eyeCenter, double faceRadius, {required bool isLeft}) {
    final r = faceRadius * 0.13;
    final isWinked = (isLeft && state == MaiFaceState.winkLeft) ||
        (!isLeft && state == MaiFaceState.winkRight);

    switch (state) {
      case MaiFaceState.happy:
        _drawHappyEye(canvas, eyeCenter, r);
      case MaiFaceState.sad:
        _drawSadEye(canvas, eyeCenter, r);
      case MaiFaceState.angry:
        _drawAngryEye(canvas, eyeCenter, r);
      default:
        if (isWinked) {
          _drawWinkEye(canvas, eyeCenter, r);
        } else {
          _drawNormalEye(canvas, eyeCenter, r);
        }
    }
  }

  void _drawNormalEye(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF3D2B1F));
    canvas.drawCircle(
      Offset(center.dx - r * 0.32, center.dy - r * 0.32),
      r * 0.28,
      Paint()..color = Colors.white,
    );
  }

  void _drawHappyEye(Canvas canvas, Offset center, double r) {
    // Upward arch (^ shape) — top half of ellipse
    final rect = Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.4);
    canvas.drawArc(
      rect,
      0,
      -math.pi, // counterclockwise = top half = arch opening downward
      false,
      Paint()
        ..color = const Color(0xFF3D2B1F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.65
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSadEye(Canvas canvas, Offset center, double r) {
    // Slightly oval, positioned a touch lower, smaller shine
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 0.08),
        width: r * 1.8,
        height: r * 1.5,
      ),
      Paint()..color = const Color(0xFF3D2B1F),
    );
    canvas.drawCircle(
      Offset(center.dx - r * 0.28, center.dy - r * 0.12),
      r * 0.22,
      Paint()..color = Colors.white,
    );
  }

  void _drawAngryEye(Canvas canvas, Offset center, double r) {
    // Squinted: narrow oval
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.9, height: r * 0.75),
      Paint()..color = const Color(0xFF3D2B1F),
    );
  }

  void _drawWinkEye(Canvas canvas, Offset center, double r) {
    // Flat closed arc (eyelid)
    canvas.drawArc(
      Rect.fromCenter(center: center, width: r * 2.1, height: r * 0.8),
      0,
      -math.pi,
      false,
      Paint()
        ..color = const Color(0xFF3D2B1F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.55
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMouth(Canvas canvas, Offset center, double faceRadius) {
    final paint = Paint()
      ..color = const Color(0xFF3D2B1F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceRadius * 0.06
      ..strokeCap = StrokeCap.round;

    final mouthY = center.dy + faceRadius * 0.35;
    final mw = faceRadius * 0.35;

    switch (state) {
      case MaiFaceState.happy:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY - mw * 0.5),
            width: mw * 2.0,
            height: mw * 1.1,
          ),
          0,
          math.pi,
          false,
          paint,
        );
      case MaiFaceState.sad:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY + mw * 0.5),
            width: mw * 1.6,
            height: mw * 0.85,
          ),
          math.pi,
          math.pi,
          false,
          paint,
        );
      case MaiFaceState.angry:
        final path = Path()
          ..moveTo(center.dx - mw * 0.65, mouthY + mw * 0.12)
          ..quadraticBezierTo(center.dx, mouthY + mw * 0.32, center.dx + mw * 0.65, mouthY + mw * 0.12);
        canvas.drawPath(path, paint);
      default:
        // Normal / wink: gentle smile
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY - mw * 0.28),
            width: mw * 1.4,
            height: mw * 0.65,
          ),
          0,
          math.pi,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(MaiFacePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.faceColor != faceColor ||
        oldDelegate.accentColor != accentColor;
  }
}
