import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../fits/models/fit.dart';
import '../../../fits/presentation/pages/fit_viewer_page.dart';
import '../../controllers/public_profile_controller.dart';
import '../../models/public_profile.dart';
import '../widgets/profile_fits_grid.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats_row.dart';

/// Someone else's profile: who they are, their record, and their fits.
///
/// The read-only twin of the profile tab — no settings, no edit button, and no
/// saved section, since what a person has bookmarked is private to them.
class PublicProfilePage extends ConsumerWidget {
  const PublicProfilePage({required this.userId, this.handle, super.key});

  /// Opens the profile of whoever owns [userId].
  ///
  /// [handle] is only what the title bar shows while the row is in flight; the
  /// loaded profile replaces it. Pass it when the caller already knows it —
  /// otherwise the bar reads "Profile" for a beat and then changes under the
  /// user.
  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? handle,
  }) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PublicProfilePage(userId: userId, handle: handle),
      ),
    );
  }

  final String userId;

  /// `@handle` if the caller had one, used as a placeholder title.
  final String? handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(userId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          AppNavigationBar(
            title: profile.value?.profile.handle ?? handle ?? 'Profile',
            showBrand: false,
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: profile.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: _ProfileError(userId: userId, error: error),
              ),
              data: (data) =>
                  _PublicProfileContent(userId: userId, profile: data),
            ),
          ),
        ],
      ),
    );
  }
}

/// The loaded profile: identity, record, and the fits they have in the arena.
class _PublicProfileContent extends ConsumerWidget {
  const _PublicProfileContent({required this.userId, required this.profile});

  final String userId;
  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reaching your own profile through a handle is possible — you can save
    // your own fit — and the viewer opened from here has to offer retiring
    // rather than reporting when it happens.
    final isOwn = ref.watch(authControllerProvider).value?.id == userId;

    return AppListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ProfileHeader(user: null, profile: profile.profile),
        const SizedBox(height: 24),
        ProfileStatsRow(stats: profile.stats),
        const SizedBox(height: 8),
        const AppSectionHeader(title: 'Fits'),
        const SizedBox(height: 4),
        if (profile.fits.isEmpty)
          const AppEmptyState(
            icon: CupertinoIcons.camera,
            title: 'No fits yet',
            message: 'Nothing of theirs is in the arena right now.',
          )
        else
          ProfileFitsGrid(
            fits: profile.fits,
            // Namespaced by owner so two profiles visited in a row cannot put
            // two live Heroes on the same tag.
            heroTagPrefix: 'public-fit-$userId',
            onFitTap: (fit, heroTag) =>
                _openFit(context, fit, heroTag, isOwn: isOwn),
          ),
      ],
    );
  }

  void _openFit(
    BuildContext context,
    Fit fit,
    Object heroTag, {
    required bool isOwn,
  }) {
    // No owner tap from here: the profile it would open is the one already on
    // screen.
    FitViewerPage.open(context, fit: fit, heroTag: heroTag, isOwn: isOwn);
  }
}

/// Why the profile is not on screen. A deleted or hidden account is an answer
/// rather than a fault, so it says so and offers nothing to retry.
class _ProfileError extends ConsumerWidget {
  const _ProfileError({required this.userId, required this.error});

  final String userId;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notFound = error is ProfileNotFoundException;

    return AppEmptyState(
      icon: notFound
          ? CupertinoIcons.person_crop_circle_badge_xmark
          : CupertinoIcons.exclamationmark_triangle,
      title: notFound ? 'Profile unavailable' : 'Could not load profile',
      message: notFound
          ? 'This account is no longer around.'
          : describeError(error),
      actionLabel: notFound ? null : 'Try again',
      onAction: notFound
          ? null
          : () => ref.invalidate(publicProfileProvider(userId)),
    );
  }
}
