import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One choice in an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Optional tally shown after the label, e.g. how many fits a section holds.
  final int? count;
}

/// Equal-width segments with a white block that glides to the selected one.
///
/// Cupertino's own sliding control paints a rounded, translucent thumb and
/// reads as a system control; this one is square-cornered and solid white,
/// which is the same language as the arena's category pills.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  }) : assert(segments.length > 1, 'A segmented control needs two segments.');

  static const _height = 36.0;
  static const _padding = 3.0;
  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  void _select(T next) {
    if (next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    final selectedIndex = segments.indexWhere(
      (segment) => segment.value == value,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth =
            (constraints.maxWidth - _padding * 2) / segments.length;

        return Container(
          height: _height,
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Stack(
            children: [
              // Nothing to slide to while the value sits outside the segments.
              if (selectedIndex >= 0)
                AnimatedPositioned(
                  duration: duration,
                  curve: _curve,
                  left: selectedIndex * segmentWidth,
                  width: segmentWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final segment in segments)
                    Expanded(
                      child: _Segment(
                        label: segment.label,
                        count: segment.count,
                        isSelected: segment.value == value,
                        duration: duration,
                        onTap: () => _select(segment.value),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool isSelected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeOut,
          style: AppTextStyles.button.copyWith(
            fontSize: 14,
            color: isSelected ? AppColors.onAccent : AppColors.textSecondary,
          ),
          child: Center(
            child: Text(
              count == null ? label : '$label  $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
