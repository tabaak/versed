import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../fits/controllers/my_fits_controller.dart';
import '../../../fits/controllers/saved_fits_controller.dart';
import '../../../fits/models/fit.dart';
import '../../controllers/profile_controller.dart';
import '../../models/profile_model.dart';
import '../widgets/profile_fits_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats_row.dart';
import 'edit_profile_page.dart';
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
    AppToast.success(context: context, message: 'Profile updated.');
  }

  Future<void> _confirmDeleteFit(Fit fit) async {
    await AppModal.showActionSheet<void>(
      context: context,
      title: 'Retire this fit?',
      message:
          'It leaves the arena for good. Battles it already fought still '
          'count for the fits it faced.',
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _deleteFit(fit);
          },
          child: const Text('Retire fit'),
        ),
      ],
    );
  }

  /// A saved fit is someone else's, so the only thing to offer is letting it
  /// go — a retired one adds the explanation for why its photo is missing.
  Future<void> _savedFitOptions(Fit fit) async {
    final handle = fit.ownerHandle;

    await AppModal.showActionSheet<void>(
      context: context,
      title: fit.isRetired
          ? 'This fit was retired'
          : handle == null
          ? 'Saved fit'
          : "$handle's fit",
      message: fit.isRetired
          ? 'It left the arena, and its photo went with it. The save is '
                'yours to keep or clear.'
          : null,
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
      AppToast.show(context: context, message: 'Removed from saved.');
    } else {
      AppToast.error(context: context, message: failure);
    }
  }

  Future<void> _deleteFit(Fit fit) async {
    try {
      await ref.read(myFitsControllerProvider.notifier).deleteFit(fit);
      if (!mounted) return;
      AppToast.success(context: context, message: 'Fit retired.');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context: context, message: describeError(error));
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
              onOwnFitTap: _confirmDeleteFit,
              onSavedFitTap: _savedFitOptions,
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
  final ValueChanged<Fit> onOwnFitTap;
  final ValueChanged<Fit> onSavedFitTap;

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
