import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../fits/presentation/widgets/fit_image.dart';

/// One outfit card on the board.
class VersusContender extends StatelessWidget {
  const VersusContender({
    required this.imagePath,
    required this.isWinner,
    required this.isLoser,
    required this.isHighlighted,
    required this.duration,
    required this.semanticLabel,
    required this.onTapDown,
    required this.onLongPress,
    super.key,
  });

  final String imagePath;
  final bool isWinner;
  final bool isLoser;
  final bool isHighlighted;
  final Duration duration;
  final String semanticLabel;
  final ValueChanged<Offset> onTapDown;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
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

    return Semantics(
      button: true,
      label: isWinner
          ? '$semanticLabel, winner'
          : '$semanticLabel, double-tap to pick as winner, '
                'long-press to report',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => onTapDown(details.globalPosition),
        onLongPress: onLongPress,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutBack,
          scale: scale,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOut,
            opacity: isLoser ? 0.55 : 1,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: isWinner ? 2 : 1),
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
                child: ExcludeSemantics(child: FitImage(imagePath: imagePath)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
