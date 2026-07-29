import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_crown_icon.dart';
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/presentation/widgets/fit_image.dart';
import 'contender_metadata.dart';

/// One outfit card on the board.
class VersusContender extends ConsumerWidget {
  const VersusContender({
    required this.fitId,
    required this.imagePath,
    required this.ownerHandle,
    required this.winCount,
    required this.isWinner,
    required this.isLoser,
    required this.isHighlighted,
    required this.isDimmed,
    required this.duration,
    required this.skeletonPhase,
    required this.semanticLabel,
    required this.onTapDown,
    required this.onLongPress,
    required this.onToggleSave,
    super.key,
  });

  final String fitId;
  final String imagePath;
  final String? ownerHandle;
  final int winCount;
  final bool isWinner;
  final bool isLoser;
  final bool isHighlighted;

  /// True while the *other* card is highlighted, so this one recedes.
  final bool isDimmed;
  final Duration duration;

  /// Offset into the loading shimmer, so the two cards do not sweep in
  /// lockstep while their photos land.
  final double skeletonPhase;
  final String semanticLabel;
  final ValueChanged<Offset> onTapDown;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSave;

  static const _highlightedElementOpacity = 0.82;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isFitSavedProvider(fitId));
    final showDetails = isHighlighted && !isWinner && !isLoser;

    final scale = isWinner
        ? 1.03
        : isLoser
        ? 0.92
        : isHighlighted
        ? 1.02
        : 1.0;
    final borderColor = isWinner
        ? AppColors.accent
        : isHighlighted
        ? AppColors.textSecondary
        : AppColors.divider;

    return AnimatedScale(
      duration: duration,
      curve: Curves.easeOutBack,
      scale: scale,
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOut,
        opacity: isLoser ? 0.55 : 1,
        // The bookmark is a sibling of the voting surface rather than a child
        // of it: nested inside, a tap on it would also be a tap on the card,
        // and the two gestures would have to fight over the pointer.
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: isWinner
                    ? '$semanticLabel, winner'
                    : '$semanticLabel, double-tap to pick as winner, '
                          'long-press to report',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => onTapDown(details.globalPosition),
                  onLongPress: onLongPress,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor,
                        width: isWinner ? 2 : 1,
                      ),
                      boxShadow: isWinner
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                blurRadius: 16,
                              ),
                            ]
                          : const [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ExcludeSemantics(
                            child: FitImage(
                              imagePath: imagePath,
                              phase: skeletonPhase,
                            ),
                          ),
                          AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOut,
                            color: const Color(
                              0xFF000000,
                            ).withValues(alpha: isDimmed ? 0.45 : 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Only on the card you just tapped once. The board is a
            // double-tap surface, so a single tap is a look rather than a
            // vote — that is the moment saving is on your mind, and it keeps
            // the bookmark off the photo the rest of the time. Gone again
            // once a winner is out: the reveal belongs to the result, and the
            // pair is about to be replaced anyway.
            Positioned(
              top: 4,
              left: 4,
              child: ExcludeSemantics(
                excluding: !showDetails,
                child: AnimatedOpacity(
                  duration: duration,
                  curve: Curves.easeOut,
                  opacity: showDetails ? _highlightedElementOpacity : 0,
                  child: IgnorePointer(
                    ignoring: !showDetails,
                    child: SaveFitButton(
                      isSaved: isSaved,
                      onPressed: onToggleSave,
                    ),
                  ),
                ),
              ),
            ),
            // Handle — bottom left, truncated to avoid overlapping wins.
            if (ownerHandle != null && ownerHandle!.trim().isNotEmpty)
              Positioned(
                left: 8,
                right: 80,
                bottom: 4,
                child: ExcludeSemantics(
                  excluding: !showDetails,
                  child: AnimatedOpacity(
                    duration: duration,
                    curve: Curves.easeOut,
                    opacity: showDetails ? _highlightedElementOpacity : 0,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: MetadataChip(
                          child: Text(
                            ownerHandle!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardMetadata,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Wins — bottom right, always in the same place.
            Positioned(
              right: 8,
              bottom: 4,
              child: ExcludeSemantics(
                excluding: !showDetails,
                child: AnimatedOpacity(
                  duration: duration,
                  curve: Curves.easeOut,
                  opacity: showDetails ? _highlightedElementOpacity : 0,
                  child: IgnorePointer(
                    child: Semantics(
                      label: '$winCount ${winCount == 1 ? 'win' : 'wins'}',
                      child: ExcludeSemantics(
                        child: MetadataChip(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppCrownIcon(),
                              const SizedBox(width: 4),
                              Text(
                                '$winCount',
                                style: AppTextStyles.cardMetadata,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bookmark that keeps a fit in the profile's saved section.
///
/// Deliberately quiet: a bare icon with no chip behind it, so it sits in the
/// corner of the photo without competing with the outfit for attention. Since
/// it now lands directly on the photo, a soft drop shadow is what keeps it
/// legible over a light outfit — the hit area stays a full [size] square
/// regardless.
class SaveFitButton extends StatefulWidget {
  const SaveFitButton({
    required this.isSaved,
    required this.onPressed,
    super.key,
  });

  static const size = 34.0;

  final bool isSaved;
  final VoidCallback onPressed;

  @override
  State<SaveFitButton> createState() => _SaveFitButtonState();
}

class _SaveFitButtonState extends State<SaveFitButton> {
  bool _pressed = false;

  void _handleTap() {
    // Saving is a keep, unsaving a discard — a light tick is the right weight
    // for both, well below the heavy impact a vote gets.
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return Semantics(
      button: true,
      label: widget.isSaved ? 'Remove from saved' : 'Save this fit',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: duration,
          curve: Curves.easeOut,
          child: SizedBox(
            width: SaveFitButton.size,
            height: SaveFitButton.size,
            child: Center(
              child: Icon(
                widget.isSaved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                size: 20,
                color: widget.isSaved
                    ? AppColors.accent
                    : AppColors.textPrimary,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
