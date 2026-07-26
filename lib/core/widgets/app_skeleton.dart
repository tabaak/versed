import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// A shimmering placeholder block, used wherever content is still loading and
/// its final shape is already known.
///
/// The sweep is a moving three-stop gradient rather than a spinner: it fills
/// the space the real content will occupy, so nothing jumps when it arrives.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.borderRadius = BorderRadius.zero,
    this.phase = 0,
    this.child,
    super.key,
  });

  final BorderRadius borderRadius;

  /// Offset into the shimmer cycle, 0–1. Staggering neighbouring skeletons by
  /// a fraction of a cycle keeps the group from pulsing as one flat block.
  final double phase;

  /// Optional content laid over the shimmer (an icon, say).
  final Widget? child;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    if (MediaQuery.disableAnimationsOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: widget.borderRadius,
        ),
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final t = (_controller.value + widget.phase) % 1;
        // The highlight travels past both edges so the band enters and leaves
        // cleanly instead of appearing mid-card.
        final center = -0.3 + t * 1.6;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: const Alignment(-1, -0.7),
              end: const Alignment(1, 0.7),
              colors: const [
                AppColors.surface,
                AppColors.elevatedSurface,
                AppColors.surface,
              ],
              stops: [
                (center - 0.3).clamp(0.0, 1.0),
                center.clamp(0.0, 1.0),
                (center + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
          child: child,
        );
      },
    );
  }
}
