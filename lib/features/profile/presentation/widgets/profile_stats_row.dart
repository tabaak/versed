import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/profile_model.dart';

/// Four-up battle record: wins, losses, win rate and current streak.
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
              value: '${stats.currentStreak}',
              label: 'Streak',
              valueColor: stats.currentStreak > 0 ? AppColors.streak : null,
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
            Text(label, maxLines: 1, style: AppTextStyles.meta),
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
