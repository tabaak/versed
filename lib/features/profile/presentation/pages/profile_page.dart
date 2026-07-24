import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../widgets/profile_fits_grid.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_settings_section.dart';
import '../widgets/profile_stats_row.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(profileProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
      ),
      child: SafeArea(
        child: AppListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ProfileHeader(
              user: user,
              profile: profile,
              onEditProfile: () => _showComingSoon('Editing your profile'),
            ),
            const SizedBox(height: 24),
            ProfileStatsRow(stats: profile.stats),
            const SizedBox(height: 24),
            const AppSectionHeader(title: 'Your fits'),
            const SizedBox(height: 8),
            if (profile.fits.isEmpty)
              const AppEmptyState(
                icon: CupertinoIcons.camera,
                title: 'No fits yet',
                message: 'Upload an outfit to enter the arena.',
              )
            else
              ProfileFitsGrid(fits: profile.fits),
            const SizedBox(height: 24),
            const AppSectionHeader(title: 'Settings'),
            const SizedBox(height: 8),
            ProfileSettingsSection(
              notificationsEnabled: _notificationsEnabled,
              onNotificationsChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
              publicProfile: _publicProfile,
              onPublicProfileChanged: (value) =>
                  setState(() => _publicProfile = value),
              onRowTap: _showComingSoon,
              onSignOut: _confirmSignOut,
              isSigningOut: _isSigningOut,
            ),
          ],
        ),
      ),
    );
  }
}
