import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_island.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/models/fit.dart';
import '../../../fits/presentation/pages/fit_viewer_page.dart';
import '../../controllers/profile_controller.dart';
import '../../models/profile_model.dart';
import '../widgets/profile_fits_grid.dart';
import '../widgets/profile_fits_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats_row.dart';
import 'edit_profile_page.dart';
import 'public_profile_page.dart';
import 'settings_page.dart';

/// The user's profile: identity, battle record, and fits. Settings live one
/// tap away, behind the gear.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  Future<void> _editProfile(ProfileSummary summary) async {
    final user = ref.read(authControllerProvider).value;
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => EditProfilePage(
          // Google's name seeds the field when the profile row has none, so
          // the user edits what the profile tab already shows them.
          initialDisplayName: summary.profile.displayName ?? user?.displayName,
          initialUsername: summary.profile.username,
          initialAvatarUrl: summary.profile.avatarUrl,
        ),
      ),
    );

    if (saved != true || !mounted) return;
    AppIsland.success(context: context, message: 'Profile updated.');
  }

  void _openOwnFit(Fit fit, Object heroTag) {
    FitViewerPage.open(context, fit: fit, heroTag: heroTag, isOwn: true);
  }

  /// A retired save has no photo left to open, so it goes straight to the
  /// options it still has instead of to the viewer.
  void _openSavedFit(Fit fit, Object heroTag) {
    if (fit.isRetired) {
      _retiredSavedFitOptions(fit);
      return;
    }

    FitViewerPage.open(
      context,
      fit: fit,
      heroTag: heroTag,
      isOwn: false,
      onOwnerTap: () => PublicProfilePage.open(
        context,
        userId: fit.ownerId,
        handle: fit.ownerHandle,
      ),
    );
  }

  Future<void> _retiredSavedFitOptions(Fit fit) async {
    await AppModal.showActionSheet<void>(
      context: context,
      title: 'This fit was retired',
      message:
          'It left the arena, and its photo went with it. The save is '
          'yours to keep or clear.',
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _removeSavedFit(fit);
          },
          child: const Text('Remove from saved'),
        ),
      ],
    );
  }

  Future<void> _removeSavedFit(Fit fit) async {
    final failure = await ref
        .read(savedFitsControllerProvider.notifier)
        .toggleSave(fit);

    if (!mounted) return;
    if (failure == null) {
      AppIsland.show(context: context, message: 'Removed from saved.');
    } else {
      AppIsland.error(context: context, message: failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(profileControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
        // The shell keeps every tab alive at once, so each tab's bar would
        // otherwise claim the same nav-bar hero tag and collide when the edit
        // page is pushed.
        transitionBetweenRoutes: false,
        // Nudges the gear in from the bar's default inset so the icon's edge
        // lines up with the 16pt content margin below it.
        padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
        trailing: AppIconButton(
          icon: CupertinoIcons.settings,
          onPressed: _openSettings,
          semanticLabel: 'Settings',
          size: 40,
          iconSize: 22,
          backgroundColor: AppColors.canvas,
          haptic: false,
        ),
      ),
      child: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: AppEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'Profile unavailable',
              message: describeError(error),
              actionLabel: 'Try again',
              onAction: () =>
                  ref.read(profileControllerProvider.notifier).refresh(),
            ),
          ),
          data: (data) {
            if (data == null) {
              return const Center(child: CupertinoActivityIndicator());
            }

            return _ProfileContent(
              summary: data,
              onEditProfile: () => _editProfile(data),
              onOwnFitTap: _openOwnFit,
              onSavedFitTap: _openSavedFit,
            );
          },
        ),
      ),
    );
  }
}

/// The loaded profile: identity, record and fits.
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.summary,
    required this.onEditProfile,
    required this.onOwnFitTap,
    required this.onSavedFitTap,
  });

  final ProfileSummary summary;
  final VoidCallback onEditProfile;
  final FitTileTapCallback onOwnFitTap;
  final FitTileTapCallback onSavedFitTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return AppListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ProfileHeader(
          user: user,
          profile: summary.profile,
          onEditProfile: onEditProfile,
        ),
        const SizedBox(height: 24),
        ProfileStatsRow(stats: summary.stats),
        const SizedBox(height: 24),
        ProfileFitsSection(
          onOwnFitTap: onOwnFitTap,
          onSavedFitTap: onSavedFitTap,
        ),
      ],
    );
  }
}
