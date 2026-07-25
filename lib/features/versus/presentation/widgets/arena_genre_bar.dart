import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../fits/models/fit_genre.dart';
import '../../controllers/arena_filter_controller.dart';

/// The category strip that heads the arena: a horizontally scrolling row of
/// pills, one per genre plus an "All" that leaves the draw to the database.
///
/// It sits where the wordmark used to, because which category you are judging
/// is the one thing about this screen worth saying at the top — and unlike the
/// wordmark, it is something you can act on.
class ArenaGenreBar extends ConsumerStatefulWidget {
  const ArenaGenreBar({super.key});

  /// Pill height plus the padding above and below the strip.
  static const height = 34.0 + 16.0;

  @override
  ConsumerState<ArenaGenreBar> createState() => _ArenaGenreBarState();
}

class _ArenaGenreBarState extends ConsumerState<ArenaGenreBar> {
  /// Null keys the "All" pill; the rest key their genre.
  final _pillKeys = <FitGenre?, GlobalKey>{
    null: GlobalKey(),
    for (final genre in FitGenre.values) genre: GlobalKey(),
  };

  /// Brings the active pill fully into view, so a selection made by scrolling
  /// to the far end does not leave the highlight half off-screen.
  void _revealSelected(FitGenre? genre) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pillContext = _pillKeys[genre]?.currentContext;
      if (pillContext == null) return;

      Scrollable.ensureVisible(
        pillContext,
        // Centres the pill when there is room to; a pill near either end just
        // settles against that end.
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _select(FitGenre? genre) {
    if (ref.read(arenaFilterControllerProvider) == genre) return;
    HapticFeedback.selectionClick();
    ref.read(arenaFilterControllerProvider.notifier).select(genre);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(arenaFilterControllerProvider);
    ref.listen<FitGenre?>(
      arenaFilterControllerProvider,
      (_, next) => _revealSelected(next),
    );

    // Genres, with "All" leading them.
    const pills = <FitGenre?>[null, ...FitGenre.values];

    return SizedBox(
      height: ArenaGenreBar.height,
      child: _EdgeFade(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          itemCount: pills.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final genre = pills[index];
            return _GenrePill(
              key: _pillKeys[genre],
              label: genre?.label ?? 'All',
              semanticLabel: genre == null
                  ? 'All categories'
                  : '${genre.label}. ${genre.description}',
              isSelected: genre == selected,
              onTap: () => _select(genre),
            );
          },
        ),
      ),
    );
  }
}

/// Softens both ends of the strip so a pill scrolling out reads as continuing
/// past the edge rather than being clipped by it.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  static const _fadeWidth = 16.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fadeStop = (_fadeWidth / bounds.width).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, fadeStop, 1 - fadeStop, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _GenrePill extends StatefulWidget {
  const _GenrePill({
    required this.label,
    required this.semanticLabel,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_GenrePill> createState() => _GenrePillState();
}

class _GenrePillState extends State<_GenrePill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          // The small squash under the finger is what makes a tap target feel
          // like an iOS control rather than a web button.
          scale: _pressed ? 0.94 : 1,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isSelected ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected ? AppColors.accent : AppColors.divider,
              ),
            ),
            child: ExcludeSemantics(
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeOut,
                style: AppTextStyles.button.copyWith(
                  fontSize: 15,
                  color: widget.isSelected
                      ? AppColors.onAccent
                      : AppColors.textPrimary,
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
