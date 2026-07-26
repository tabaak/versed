import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_skeleton.dart';
import 'matchup_board.dart';

/// The board's shape while the first matchup is still loading: two shimmering
/// cards and the VS badge, laid out with the same [MatchupBoardMetrics] the
/// real board uses, so the photos fade in exactly where the placeholders were.
class MatchupBoardSkeleton extends StatelessWidget {
  const MatchupBoardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = MatchupBoardMetrics(constraints);
        final borderRadius = BorderRadius.circular(8);

        Widget card({required double phase}) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: AppColors.divider),
            ),
            child: AppSkeleton(
              borderRadius: BorderRadius.circular(7),
              phase: phase,
            ),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: metrics.leftCardTop,
              width: metrics.cardWidth,
              height: metrics.cardHeight,
              // A small offset between the two sweeps reads as one board
              // waking up rather than two blocks blinking together.
              child: card(phase: 0.12),
            ),
            Positioned(
              right: 0,
              top: metrics.topInset,
              width: metrics.cardWidth,
              height: metrics.cardHeight,
              child: card(phase: 0),
            ),
            Positioned(
              left: metrics.badgeOffset.dx,
              top: metrics.badgeOffset.dy,
              child: SizedBox.fromSize(
                size: MatchupBoardMetrics.badgeSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.canvas, width: 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
