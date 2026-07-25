import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../fits/models/fit_genre.dart';

/// Chooses the genre a staged fit will battle in.
///
/// A horizontal strip rather than a picker wheel or a dropdown: the genre
/// decides who the fit is ever compared against, so every option should be
/// visible at a glance instead of hidden behind a tap.
class GenrePicker extends StatelessWidget {
  const GenrePicker({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final FitGenre? selected;
  final ValueChanged<FitGenre> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: FitGenre.values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final genre = FitGenre.values[index];
              return _GenreChip(
                genre: genre,
                isSelected: genre == selected,
                onTap: enabled ? () => onSelected(genre) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Reserves the line whether or not anything is selected, so picking a
        // genre does not shift the buttons below.
        Text(
          selected?.description ?? 'Pick the genre this fit competes in',
          style: AppTextStyles.meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  final FitGenre genre;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${genre.label}. ${genre.description}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.divider,
            ),
          ),
          child: ExcludeSemantics(
            child: Text(
              genre.label,
              style: AppTextStyles.button.copyWith(
                color: isSelected ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
