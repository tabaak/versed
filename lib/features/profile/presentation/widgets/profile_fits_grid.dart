import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/profile_model.dart';

/// Three-up grid of the user's fits, each tile showing its win record.
class ProfileFitsGrid extends StatelessWidget {
  const ProfileFitsGrid({required this.fits, super.key});

  static const _spacing = 8.0;
  static const _columns = 3;

  final List<ProfileFit> fits;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - _spacing * (_columns - 1)) / _columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final fit in fits)
              SizedBox(width: tileWidth, child: _FitTile(fit: fit)),
          ],
        );
      },
    );
  }
}

class _FitTile extends StatelessWidget {
  const _FitTile({required this.fit});

  final ProfileFit fit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Fit with ${fit.wins} wins from ${fit.battles} battles',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(fit.asset, fit: BoxFit.cover),
                // Keeps the win badge legible over bright outfit photos.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xB3000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.rosette,
                        size: 12,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${fit.wins}/${fit.battles}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.tabularMetric.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
