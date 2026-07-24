import 'package:flutter/cupertino.dart';

/// One emoji thrown from the tap point when a winner is crowned.
class EmojiBurst {
  const EmojiBurst({
    required this.id,
    required this.position,
    required this.emoji,
    required this.velocity,
    required this.tilt,
  });

  final int id;
  final Offset position;
  final String emoji;
  final Offset velocity;
  final double tilt;
}

class EmojiBurstParticle extends StatelessWidget {
  const EmojiBurstParticle({
    required this.burst,
    required this.onCompleted,
    super.key,
  });

  final EmojiBurst burst;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: burst.position.dx - 12,
      top: burst.position.dy - 12,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          onEnd: onCompleted,
          builder: (context, progress, child) {
            // Projectile motion: launch along the burst velocity, then fall.
            const gravity = 560.0;
            final t = progress * 0.9;
            final offset = Offset(
              burst.velocity.dx * t,
              burst.velocity.dy * t + 0.5 * gravity * t * t,
            );
            final fade = progress < 0.6 ? 1.0 : 1 - (progress - 0.6) / 0.4;

            return Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: burst.tilt * progress * 2,
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.7 + 0.4 * progress,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: Text(
            burst.emoji,
            style: const TextStyle(fontSize: 24, height: 1),
          ),
        ),
      ),
    );
  }
}
