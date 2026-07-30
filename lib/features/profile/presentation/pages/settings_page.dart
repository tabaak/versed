import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/app_island.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../widgets/profile_settings_section.dart';

/// Everything the profile tab used to carry below the fits: preferences,
/// account rows, and sign-out.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local-only until the settings backend exists.
  bool _notificationsEnabled = true;
  bool _publicProfile = true;
  bool _isSigningOut = false;

  void _showComingSoon(String label) {
    AppIsland.show(context: context, message: '$label is coming soon.');
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
    if (!mounted) return;

    // The auth gate swaps the app out underneath, but this page is pushed on
    // top of it — so it has to step aside itself. A failed sign-out stays put
    // and hands the switch back.
    if (ref.read(authControllerProvider).hasError) {
      setState(() => _isSigningOut = false);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          AppNavigationBar(
            title: 'Settings',
            showBrand: false,
            onBack: _isSigningOut ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: AppListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
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
        ],
      ),
    );
  }
}
