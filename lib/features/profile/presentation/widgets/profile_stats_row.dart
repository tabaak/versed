import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/profile_model.dart';

/// Four-up battle record: wins, losses, win rate and best streak.
///
/// The streak carries the amber even though it is a record rather than a run
/// in progress — it is the one number here that is not a plain tally, and the
/// colour is what says so at a glance.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({required this.stats, super.key});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _Stat(value: '${stats.wins}', label: 'Wins'),
            const _Divider(),
            _Stat(value: '${stats.losses}', label: 'Losses'),
            const _Divider(),
            _Stat(value: '${stats.winRate}%', label: 'Win rate'),
            const _Divider(),
            _Stat(
              value: '${stats.bestStreak}',
              label: 'Best streak',
              // A profile that has never won anything has no record to
              // colour, and a gold zero reads as a bug.
              valueColor: stats.bestStreak > 0 ? AppColors.streak : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;

  /// Amber for the streak; the other three stay white.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        container: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              style: AppTextStyles.tabularMetric.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // "Best streak" is the widest of the four labels and the cells are
            // even, so it sets the floor — shrink rather than ellipsize when
            // the screen is narrow or the text scale is up.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: AppTextStyles.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 32,
      child: ColoredBox(color: AppColors.divider),
    );
  }
}
