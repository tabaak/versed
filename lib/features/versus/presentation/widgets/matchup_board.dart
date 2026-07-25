import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/matchup.dart';
import 'versus_contender.dart';

/// The diagonal two-card board: bottom-left versus top-right, VS badge at the
/// seam.
class MatchupBoard extends StatelessWidget {
  const MatchupBoard({
    required this.matchup,
    required this.winner,
    required this.highlighted,
    required this.animationsDisabled,
    required this.onTapDown,
    required this.onLongPress,
    super.key,
  });

  final Matchup matchup;
  final VersusSide? winner;
  final VersusSide? highlighted;
  final bool animationsDisabled;
  final void Function(VersusSide side, Offset globalPosition) onTapDown;
  final ValueChanged<VersusSide> onLongPress;

  @override
  Widget build(BuildContext context) {
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cards sit diagonally (bottom-left vs top-right) and overlap a
        // little vertically, so each one can be far larger than in a
        // side-by-side split.
        const aspectRatio = 4 / 5;
        const overlapFraction = 0.06;

        final cardWidth = min(
          0.72 * constraints.maxWidth,
          constraints.maxHeight * aspectRatio / (2 - overlapFraction),
        );
        final cardHeight = cardWidth / aspectRatio;
        final pairHeight = (2 - overlapFraction) * cardHeight;
        // Anchor the pair near the top; leftover space stays at the bottom.
        final topInset = min((constraints.maxHeight - pairHeight) / 2, 12.0);

        final leftCard = Positioned(
          key: const ValueKey(VersusSide.left),
          left: 0,
          top: topInset + (1 - overlapFraction) * cardHeight,
          width: cardWidth,
          height: cardHeight,
          child: VersusContender(
            imagePath: matchup.left.imagePath,
            isWinner: winner == VersusSide.left,
            isLoser: winner == VersusSide.right,
            isHighlighted: highlighted == VersusSide.left,
            isDimmed: highlighted == VersusSide.right,
            duration: duration,
            semanticLabel: 'Bottom left outfit',
            onTapDown: (globalPosition) =>
                onTapDown(VersusSide.left, globalPosition),
            onLongPress: () => onLongPress(VersusSide.left),
          ),
        );
        final rightCard = Positioned(
          key: const ValueKey(VersusSide.right),
          right: 0,
          top: topInset,
          width: cardWidth,
          height: cardHeight,
          child: VersusContender(
            imagePath: matchup.right.imagePath,
            isWinner: winner == VersusSide.right,
            isLoser: winner == VersusSide.left,
            isHighlighted: highlighted == VersusSide.right,
            isDimmed: highlighted == VersusSide.left,
            duration: duration,
            semanticLabel: 'Top right outfit',
            onTapDown: (globalPosition) =>
                onTapDown(VersusSide.right, globalPosition),
            onLongPress: () => onLongPress(VersusSide.right),
          ),
        );

        // The active card (winner, or highlighted) renders on top.
        final leftOnTop =
            winner == VersusSide.left ||
            (winner == null && highlighted == VersusSide.left);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (leftOnTop) ...[
              rightCard,
              leftCard,
            ] else ...[
              leftCard,
              rightCard,
            ],
            // The badge sits in the free column right of the bottom card,
            // level with the seam between the two cards.
            Positioned(
              left: cardWidth - 44 + (constraints.maxWidth - cardWidth) / 2 + 2,
              top: topInset + pairHeight / 2 - 16 + 31,
              child: AnimatedOpacity(
                duration: animationsDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                opacity: winner == null ? 1 : 0,
                child: Container(
                  width: 44,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.canvas, width: 2),
                  ),
                  child: const Text('VS', style: AppTextStyles.matchupDivider),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
