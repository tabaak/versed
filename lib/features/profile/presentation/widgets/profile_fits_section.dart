import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import '../../../fits/controllers/my_fits_controller.dart';
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/models/fit.dart';
import 'profile_fits_grid.dart';

/// The two grids a profile holds.
enum ProfileFitsTab { own, saved }

/// The fits half of the profile: a segmented switch between the user's own
/// fits and the ones they saved, over the grid for whichever is selected.
///
/// Which tab is showing is pure interface state, so it lives here rather than
/// in a controller — nothing outside this widget acts on it.
class ProfileFitsSection extends ConsumerStatefulWidget {
  const ProfileFitsSection({
    required this.onOwnFitTap,
    required this.onSavedFitTap,
    super.key,
  });

  final ValueChanged<Fit> onOwnFitTap;
  final ValueChanged<Fit> onSavedFitTap;

  @override
  ConsumerState<ProfileFitsSection> createState() => _ProfileFitsSectionState();
}

class _ProfileFitsSectionState extends ConsumerState<ProfileFitsSection> {
  ProfileFitsTab _tab = ProfileFitsTab.own;

  @override
  Widget build(BuildContext context) {
    final own = ref.watch(myFitsControllerProvider);
    final saved = ref.watch(savedFitsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedControl<ProfileFitsTab>(
          value: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
          segments: [
            AppSegment(
              value: ProfileFitsTab.own,
              label: 'Your fits',
              // Counts only once loaded; a count that flickers in from nothing
              // is worse than one that arrives with the grid.
              count: own.value?.length,
            ),
            AppSegment(
              value: ProfileFitsTab.saved,
              label: 'Saved',
              count: saved.value?.length,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_tab) {
            ProfileFitsTab.own => _OwnFits(
              key: const ValueKey(ProfileFitsTab.own),
              fits: own,
              onFitTap: widget.onOwnFitTap,
            ),
            ProfileFitsTab.saved => _SavedFits(
              key: const ValueKey(ProfileFitsTab.saved),
              fits: saved,
              onFitTap: widget.onSavedFitTap,
            ),
          },
        ),
      ],
    );
  }
}

class _OwnFits extends ConsumerWidget {
  const _OwnFits({required this.fits, required this.onFitTap, super.key});

  final AsyncValue<List<Fit>> fits;
  final ValueChanged<Fit> onFitTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return fits.when(
      loading: () => const _GridLoading(),
      error: (error, _) => AppEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Fits unavailable',
        message: describeError(error),
        actionLabel: 'Try again',
        onAction: () => ref.read(myFitsControllerProvider.notifier).refresh(),
      ),
      data: (items) => items.isEmpty
          ? const AppEmptyState(
              icon: CupertinoIcons.camera,
              title: 'No fits yet',
              message: 'Upload an outfit to enter the arena.',
            )
          : ProfileFitsGrid(fits: items, onFitTap: onFitTap),
    );
  }
}

class _SavedFits extends ConsumerWidget {
  const _SavedFits({required this.fits, required this.onFitTap, super.key});

  final AsyncValue<List<Fit>> fits;
  final ValueChanged<Fit> onFitTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return fits.when(
      loading: () => const _GridLoading(),
      error: (error, _) => AppEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Saved fits unavailable',
        message: describeError(error),
        actionLabel: 'Try again',
        onAction: () =>
            ref.read(savedFitsControllerProvider.notifier).refresh(),
      ),
      data: (items) => items.isEmpty
          ? const AppEmptyState(
              icon: CupertinoIcons.bookmark,
              title: 'Nothing saved yet',
              message:
                  'Tap the bookmark on a fit in the arena to keep it here. '
                  'Only you can see what you save.',
            )
          : ProfileFitsGrid(fits: items, onFitTap: onFitTap, showOwner: true),
    );
  }
}

class _GridLoading extends StatelessWidget {
  const _GridLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}
