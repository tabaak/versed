import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// A compact vector crown that stays crisp without an emoji or icon package.
class AppCrownIcon extends StatelessWidget {
  const AppCrownIcon({
    this.size = 15,
    this.color = AppColors.textPrimary,
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CrownPainter(color: color),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.25)
      ..lineTo(size.width * 0.28, size.height * 0.45)
      ..lineTo(size.width * 0.5, size.height * 0.12)
      ..lineTo(size.width * 0.72, size.height * 0.45)
      ..lineTo(size.width * 0.92, size.height * 0.25)
      ..lineTo(size.width * 0.83, size.height * 0.78)
      ..lineTo(size.width * 0.17, size.height * 0.78)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(path, paint)
      ..drawLine(
        Offset(size.width * 0.2, size.height * 0.63),
        Offset(size.width * 0.8, size.height * 0.63),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
