import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../fits/controllers/my_fits_controller.dart';
import '../../../fits/models/fit.dart';
import '../../controllers/profile_controller.dart';
import '../../models/profile_model.dart';
import '../widgets/profile_fits_grid.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_settings_section.dart';
import '../widgets/profile_stats_row.dart';
import 'edit_profile_page.dart';

/// The user's profile: identity, battle record, fits, and settings.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // Local-only until the settings backend exists.
  bool _notificationsEnabled = true;
  bool _publicProfile = true;
  bool _isSigningOut = false;

  void _showComingSoon(String label) {
    AppToast.show(context: context, message: '$label is coming soon.');
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
        ),
      ),
    );

    if (saved != true || !mounted) return;
    AppToast.success(context: context, message: 'Profile updated.');
  }

  Future<void> _confirmSignOut() async {
    await AppModal.showActionSheet<void>(
      context: context,
      title: 'Sign out of VERSED?',
      message: 'Your fits and battle record stay on your account.',
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _signOut();
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await ref.read(authControllerProvider.notifier).signOut();
    // The auth gate swaps this page out on success, so only a failed sign-out
    // gets here still mounted.
    if (mounted) setState(() => _isSigningOut = false);
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
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
        // The shell keeps every tab alive at once, so each tab's bar would
        // otherwise claim the same nav-bar hero tag and collide when the edit
        // page is pushed.
        transitionBetweenRoutes: false,
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
              notificationsEnabled: _notificationsEnabled,
              onNotificationsChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              publicProfile: _publicProfile,
              onPublicProfileChanged: (value) =>
                  setState(() => _publicProfile = value),
              onRowTap: _showComingSoon,
              onEditProfile: () => _editProfile(data),
              onSignOut: _confirmSignOut,
              isSigningOut: _isSigningOut,
              onFitTap: _confirmDeleteFit,
            );
          },
        ),
      ),
    );
  }
}

/// The loaded profile: identity, record, fits and settings.
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.summary,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.publicProfile,
    required this.onPublicProfileChanged,
    required this.onRowTap,
    required this.onEditProfile,
    required this.onSignOut,
    required this.isSigningOut,
    required this.onFitTap,
  });

  final ProfileSummary summary;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool publicProfile;
  final ValueChanged<bool> onPublicProfileChanged;
  final ValueChanged<String> onRowTap;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;
  final bool isSigningOut;
  final ValueChanged<Fit> onFitTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final fits = ref.watch(myFitsControllerProvider);

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
        const AppSectionHeader(title: 'Your fits'),
        const SizedBox(height: 8),
        fits.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, _) => AppEmptyState(
            icon: CupertinoIcons.exclamationmark_triangle,
            title: 'Fits unavailable',
            message: describeError(error),
            actionLabel: 'Try again',
            onAction: () =>
                ref.read(myFitsControllerProvider.notifier).refresh(),
          ),
          data: (items) => items.isEmpty
              ? const AppEmptyState(
                  icon: CupertinoIcons.camera,
                  title: 'No fits yet',
                  message: 'Upload an outfit to enter the arena.',
                )
              : ProfileFitsGrid(fits: items, onFitTap: onFitTap),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(title: 'Settings'),
        const SizedBox(height: 8),
        ProfileSettingsSection(
          notificationsEnabled: notificationsEnabled,
          onNotificationsChanged: onNotificationsChanged,
          publicProfile: publicProfile,
          onPublicProfileChanged: onPublicProfileChanged,
          onRowTap: onRowTap,
          onSignOut: onSignOut,
          isSigningOut: isSigningOut,
        ),
      ],
    );
  }
}
