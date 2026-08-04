import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_crown_icon.dart';
import '../../../../core/widgets/app_flame_icon.dart';
import '../../models/fit.dart';

/// Everything that sits under the photo in the viewer: who owns it, how it has
/// been doing, and what you can do with it.
class FitViewerDetails extends StatelessWidget {
  const FitViewerDetails({
    required this.fit,
    required this.showOwner,
    required this.isSaved,
    required this.isSharing,
    required this.onToggleSave,
    required this.onShare,
    super.key,
  });

  final Fit fit;

  /// Off for your own fits — the handle would only ever be your own.
  final bool showOwner;
  final bool isSaved;

  /// True while the photo is being pulled down for the share sheet.
  final bool isSharing;

  final VoidCallback onToggleSave;
  final ValueChanged<Rect?> onShare;

  @override
  Widget build(BuildContext context) {
    final handle = showOwner ? fit.ownerHandle : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (handle != null) ...[
          Text(
            handle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 8),
        ],
        FitViewerStats(fit: fit),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FitViewerActionButton(
                icon: isSaved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                label: isSaved ? 'Saved' : 'Save',
                semanticLabel: isSaved ? 'Remove from saved' : 'Save this fit',
                onPressed: onToggleSave,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FitViewerActionButton(
                icon: CupertinoIcons.share,
                label: 'Share',
                semanticLabel: 'Share or download this photo',
                busy: isSharing,
                // The share sheet is a popover on iPad and needs the rect of
                // whatever opened it, so the button reports its own position.
                onPressedWithOrigin: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Views, win rate, and a streak when there is one, side by side.
///
/// "Views" counts the battles the fit has fought: every battle is one person
/// looking at it in the arena, and it is the only impression the app records.
///
/// The streak only joins them while the fit is actually on a run, which is the
/// one thing here that can disappear — a rate settles down, a run is news.
class FitViewerStats extends StatelessWidget {
  const FitViewerStats({required this.fit, super.key});

  final Fit fit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: '${fit.battles} ${fit.battles == 1 ? 'view' : 'views'}',
          child: ExcludeSemantics(
            child: _Stat(
              icon: const Icon(
                CupertinoIcons.eye,
                size: 15,
                color: AppColors.textSecondary,
              ),
              value: '${fit.battles}',
              label: fit.battles == 1 ? 'view' : 'views',
            ),
          ),
        ),
        const SizedBox(width: 20),
        Semantics(
          label: '${fit.winRate} percent win rate',
          child: ExcludeSemantics(
            child: _Stat(
              icon: const AppCrownIcon(
                size: 14,
                color: AppColors.textSecondary,
              ),
              value: '${fit.winRate}%',
              label: 'win rate',
            ),
          ),
        ),
        if (fit.isOnStreak) ...[
          const SizedBox(width: 20),
          Semantics(
            label: '${fit.currentStreak} wins in a row',
            child: ExcludeSemantics(
              child: _Stat(
                icon: const AppFlameIcon(size: 14),
                value: '${fit.currentStreak}',
                label: 'in a row',
                valueColor: AppColors.streak,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final Widget icon;
  final String value;
  final String label;

  /// Amber for a live streak; the rest of the row stays monochrome.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          value,
          style: valueColor == null
              ? AppTextStyles.tabularMetric
              : AppTextStyles.tabularMetric.copyWith(color: valueColor),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.meta),
      ],
    );
  }
}

/// A wide icon-and-label button, sized for the pair under the photo.
class FitViewerActionButton extends StatefulWidget {
  const FitViewerActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.onPressed,
    this.onPressedWithOrigin,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Same as [onPressed], but handed the button's global rect — what a
  /// Cupertino popover needs to know where to point.
  final ValueChanged<Rect?>? onPressedWithOrigin;

  /// Swaps the icon for a spinner and stops further taps.
  final bool busy;

  @override
  State<FitViewerActionButton> createState() => _FitViewerActionButtonState();
}

class _FitViewerActionButtonState extends State<FitViewerActionButton> {
  bool _pressed = false;

  bool get _isEnabled =>
      !widget.busy &&
      (widget.onPressed != null || widget.onPressedWithOrigin != null);

  void _setPressed(bool value) {
    if (_isEnabled && _pressed != value) setState(() => _pressed = value);
  }

  Future<void> _handleTap() async {
    if (!_isEnabled) return;
    await HapticFeedback.lightImpact();

    widget.onPressed?.call();
    widget.onPressedWithOrigin?.call(_globalRect());
  }

  /// Null when the button has been disposed out from under the gesture.
  Rect? _globalRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 48,
          decoration: BoxDecoration(
            color: _pressed ? AppColors.elevatedSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                const CupertinoActivityIndicator(radius: 9)
              else
                Icon(widget.icon, size: 19, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: AppTextStyles.button.copyWith(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
