import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// A compact vector flame, the mark for an active win streak.
///
/// Filled rather than stroked like the crown: the crown labels a number that
/// is always there, while this one only appears when a fit is on a run and has
/// to read at a glance against a photo.
class AppFlameIcon extends StatelessWidget {
  const AppFlameIcon({
    this.size = 13,
    this.color = AppColors.streak,
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FlamePainter(color: color),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer flame: a teardrop leaning off the tip, drawn from the top down the
    // right side and back up the left.
    final flame = Path()
      ..moveTo(w * 0.52, h * 0.04)
      ..cubicTo(w * 0.58, h * 0.30, w * 0.94, h * 0.40, w * 0.86, h * 0.66)
      ..cubicTo(w * 0.80, h * 0.88, w * 0.62, h * 0.98, w * 0.48, h * 0.98)
      ..cubicTo(w * 0.26, h * 0.98, w * 0.10, h * 0.83, w * 0.10, h * 0.62)
      ..cubicTo(w * 0.10, h * 0.38, w * 0.34, h * 0.34, w * 0.52, h * 0.04)
      ..close();

    // Inner core, punched out so the flame keeps its shape at 13px instead of
    // filling in as a blob.
    final core = Path()
      ..moveTo(w * 0.50, h * 0.46)
      ..cubicTo(w * 0.56, h * 0.60, w * 0.68, h * 0.62, w * 0.64, h * 0.76)
      ..cubicTo(w * 0.60, h * 0.88, w * 0.50, h * 0.90, w * 0.43, h * 0.86)
      ..cubicTo(w * 0.34, h * 0.80, w * 0.36, h * 0.62, w * 0.50, h * 0.46)
      ..close();

    canvas.drawPath(
      Path.combine(PathOperation.difference, flame, core),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
