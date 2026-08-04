import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_crown_icon.dart';
import '../../../../core/widgets/app_flame_icon.dart';

/// The owner and win count revealed along the foot of a contender.
class ContenderMetadata extends StatelessWidget {
  const ContenderMetadata({
    required this.handle,
    required this.winCount,
    super.key,
  });

  final String? handle;
  final int winCount;

  @override
  Widget build(BuildContext context) {
    final normalizedHandle = handle?.trim();
    final showHandle = normalizedHandle != null && normalizedHandle.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showHandle)
          Flexible(
            child: MetadataChip(
              child: Text(
                normalizedHandle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardMetadata,
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(width: 8),
        Semantics(
          label: '$winCount ${winCount == 1 ? 'win' : 'wins'}',
          child: ExcludeSemantics(
            child: MetadataChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppCrownIcon(),
                  const SizedBox(width: 4),
                  Text('$winCount', style: AppTextStyles.cardMetadata),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The amber run-in-progress badge: a flame and the number of straight wins.
///
/// Amber is spent here and nowhere else, so a card wearing one is the only
/// colour on the board.
class StreakChip extends StatelessWidget {
  const StreakChip({required this.streak, super.key});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$streak wins in a row',
      child: ExcludeSemantics(
        child: MetadataChip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppFlameIcon(),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: AppTextStyles.cardMetadata.copyWith(
                  color: AppColors.streak,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetadataChip extends StatelessWidget {
  const MetadataChip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}
