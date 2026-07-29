import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_crown_icon.dart';
import '../../../fits/models/fit.dart';
import '../../../fits/presentation/widgets/fit_image.dart';

/// Three-up grid of fits, each tile showing its win rate.
///
/// Backs both profile sections: the user's own fits, and the ones they saved.
/// The saved section turns [showOwner] on, since those fits belong to other
/// people, and is the only one that can contain retired fits.
class ProfileFitsGrid extends StatelessWidget {
  const ProfileFitsGrid({
    required this.fits,
    required this.onFitTap,
    this.showOwner = false,
    super.key,
  });

  static const _spacing = 8.0;
  static const _columns = 3;

  final List<Fit> fits;
  final ValueChanged<Fit> onFitTap;

  /// Captions each tile with the handle of whoever owns the fit.
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - _spacing * (_columns - 1)) / _columns;

        // Claims the full width even when the fits do not fill a row. A Wrap
        // shrink-wraps its content, and a half-empty row handed to something
        // that centers loose children — the section's AnimatedSwitcher does
        // exactly that — would drift into the middle instead of starting at
        // the left edge like a grid.
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            children: [
              for (final fit in fits)
                SizedBox(
                  width: tileWidth,
                  child: _FitTile(
                    fit: fit,
                    showOwner: showOwner,
                    onTap: () => onFitTap(fit),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FitTile extends StatelessWidget {
  const _FitTile({
    required this.fit,
    required this.showOwner,
    required this.onTap,
  });

  final Fit fit;
  final bool showOwner;
  final VoidCallback onTap;

  String get _semanticLabel {
    final owner = showOwner ? '${fit.ownerHandle ?? 'Someone'}. ' : '';
    if (fit.isRetired) {
      return '${owner}This fit was retired. Tap for options.';
    }
    return '${owner}Fit with a ${fit.winRate}% win rate. Tap for options.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: fit.isRetired
                  ? const _RetiredTile()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        FitImage(imagePath: fit.imagePath),
                        // Keeps the caption legible over bright outfit photos.
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
                          child: _TileCaption(fit: fit, showOwner: showOwner),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stands in for a fit that has left the arena.
///
/// Its photo is purged from storage the moment its owner retires it, so there
/// is nothing left to render — but the tile stays, because a save quietly
/// vanishing from the grid is worse than one that says what happened.
class _RetiredTile extends StatelessWidget {
  const _RetiredTile();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.archivebox,
                size: 22,
                color: AppColors.textTertiary,
              ),
              SizedBox(height: 6),
              Text(
                'Retired',
                textAlign: TextAlign.center,
                style: AppTextStyles.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The win rate, plus the owner's handle when the tile is someone else's.
class _TileCaption extends StatelessWidget {
  const _TileCaption({required this.fit, required this.showOwner});

  final Fit fit;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final handle = showOwner ? fit.ownerHandle : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (handle != null)
          Text(
            handle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.meta.copyWith(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
          ),
        Row(
          children: [
            const AppCrownIcon(size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${fit.winRate}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.tabularMetric.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
