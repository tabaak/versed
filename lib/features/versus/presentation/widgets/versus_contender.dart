import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/presentation/widgets/fit_image.dart';

/// One outfit card on the board.
class VersusContender extends ConsumerWidget {
  const VersusContender({
    required this.fitId,
    required this.imagePath,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isFitSavedProvider(fitId));

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
            // Hidden once a winner is out: the reveal belongs to the result,
            // and the pair is about to be replaced anyway.
            Positioned(
              bottom: 8,
              left: 8,
              child: AnimatedOpacity(
                duration: duration,
                curve: Curves.easeOut,
                opacity: isWinner || isLoser ? 0 : 1,
                child: IgnorePointer(
                  ignoring: isWinner || isLoser,
                  child: SaveFitButton(
                    isSaved: isSaved,
                    onPressed: onToggleSave,
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
/// Deliberately quiet: a barely-there chip rather than a filled control, so it
/// sits in the corner of the photo without competing with the outfit for
/// attention. The icon stays fully opaque even as its backing fades — the chip
/// is what recedes, not the thing you have to aim at.
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
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            width: SaveFitButton.size,
            height: SaveFitButton.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isSaved
                  ? AppColors.accent
                  : AppColors.canvas.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSaved
                    ? AppColors.accent
                    // Softened along with the fill: an opaque hairline around
                    // a near-transparent chip reads as the heavier element.
                    : AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              widget.isSaved
                  ? CupertinoIcons.bookmark_fill
                  : CupertinoIcons.bookmark,
              size: 16,
              color: widget.isSaved
                  ? AppColors.onAccent
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
