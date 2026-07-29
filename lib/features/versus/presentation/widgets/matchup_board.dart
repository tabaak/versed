import 'dart:math';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/matchup.dart';
import 'versus_contender.dart';

/// Where the two cards and the VS badge sit for a given board size.
///
/// Shared with the loading skeleton so the placeholders occupy exactly the
/// space the real cards will, and the swap is a cross-fade with no reflow.
class MatchupBoardMetrics {
  factory MatchupBoardMetrics(BoxConstraints constraints) {
    final cardWidth = min(
      0.72 * constraints.maxWidth,
      constraints.maxHeight * _aspectRatio / (2 - _overlapFraction),
    );
    final cardHeight = cardWidth / _aspectRatio;
    final pairHeight = (2 - _overlapFraction) * cardHeight;

    return MatchupBoardMetrics._(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      pairHeight: pairHeight,
      // Anchor the pair near the top; leftover space stays at the bottom.
      topInset: min((constraints.maxHeight - pairHeight) / 2, 12.0),
      boardWidth: constraints.maxWidth,
    );
  }

  const MatchupBoardMetrics._({
    required this.cardWidth,
    required this.cardHeight,
    required this.pairHeight,
    required this.topInset,
    required this.boardWidth,
  });

  // Cards sit diagonally (bottom-left vs top-right) and overlap a little
  // vertically, so each one can be far larger than in a side-by-side split.
  static const _aspectRatio = 4 / 5;
  static const _overlapFraction = 0.06;

  final double cardWidth;
  final double cardHeight;
  final double pairHeight;
  final double topInset;
  final double boardWidth;

  /// Top of the bottom-left card.
  double get leftCardTop => topInset + (1 - _overlapFraction) * cardHeight;

  /// Top-left of the VS badge, in the free column right of the bottom card and
  /// level with the seam between the two cards.
  Offset get badgeOffset => Offset(
    cardWidth - 44 + (boardWidth - cardWidth) / 2 + 2,
    topInset + pairHeight / 2 - 16 + 31,
  );

  static const badgeSize = Size(44, 32);
}

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
    required this.onToggleSave,
    super.key,
  });

  final Matchup matchup;
  final VersusSide? winner;
  final VersusSide? highlighted;
  final bool animationsDisabled;
  final void Function(VersusSide side, Offset globalPosition) onTapDown;
  final ValueChanged<VersusSide> onLongPress;
  final ValueChanged<VersusSide> onToggleSave;

  @override
  Widget build(BuildContext context) {
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = MatchupBoardMetrics(constraints);

        final leftCard = Positioned(
          key: const ValueKey(VersusSide.left),
          left: 0,
          top: metrics.leftCardTop,
          width: metrics.cardWidth,
          height: metrics.cardHeight,
          child: VersusContender(
            fitId: matchup.left.id,
            imagePath: matchup.left.imagePath,
            ownerHandle: matchup.left.ownerHandle,
            winCount: matchup.left.wins,
            isWinner: winner == VersusSide.left,
            isLoser: winner == VersusSide.right,
            isHighlighted: highlighted == VersusSide.left,
            isDimmed: highlighted == VersusSide.right,
            duration: duration,
            skeletonPhase: 0.12,
            semanticLabel: 'Bottom left outfit',
            onTapDown: (globalPosition) =>
                onTapDown(VersusSide.left, globalPosition),
            onLongPress: () => onLongPress(VersusSide.left),
            onToggleSave: () => onToggleSave(VersusSide.left),
          ),
        );
        final rightCard = Positioned(
          key: const ValueKey(VersusSide.right),
          right: 0,
          top: metrics.topInset,
          width: metrics.cardWidth,
          height: metrics.cardHeight,
          child: VersusContender(
            fitId: matchup.right.id,
            imagePath: matchup.right.imagePath,
            ownerHandle: matchup.right.ownerHandle,
            winCount: matchup.right.wins,
            isWinner: winner == VersusSide.right,
            isLoser: winner == VersusSide.left,
            isHighlighted: highlighted == VersusSide.right,
            isDimmed: highlighted == VersusSide.left,
            duration: duration,
            skeletonPhase: 0,
            semanticLabel: 'Top right outfit',
            onTapDown: (globalPosition) =>
                onTapDown(VersusSide.right, globalPosition),
            onLongPress: () => onLongPress(VersusSide.right),
            onToggleSave: () => onToggleSave(VersusSide.right),
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
            Positioned(
              left: metrics.badgeOffset.dx,
              top: metrics.badgeOffset.dy,
              child: AnimatedOpacity(
                duration: animationsDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                opacity: winner == null ? 1 : 0,
                child: Container(
                  width: MatchupBoardMetrics.badgeSize.width,
                  height: MatchupBoardMetrics.badgeSize.height,
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
