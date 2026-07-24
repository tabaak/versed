import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_toggle.dart';

/// Inset-grouped settings rows plus the sign-out action.
class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.publicProfile,
    required this.onPublicProfileChanged,
    required this.onRowTap,
    required this.onSignOut,
    this.isSigningOut = false,
    super.key,
  });

  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final bool publicProfile;
  final ValueChanged<bool> onPublicProfileChanged;
  final ValueChanged<String> onRowTap;
  final VoidCallback onSignOut;
  final bool isSigningOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsGroup(
          children: [
            ProfileSettingsRow(
              icon: CupertinoIcons.bell,
              label: 'Notifications',
              trailing: AppToggleSwitch(
                value: notificationsEnabled,
                onChanged: onNotificationsChanged,
                semanticLabel: 'Notifications',
              ),
            ),
            ProfileSettingsRow(
              icon: CupertinoIcons.eye,
              label: 'Public profile',
              trailing: AppToggleSwitch(
                value: publicProfile,
                onChanged: onPublicProfileChanged,
                semanticLabel: 'Public profile',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            ProfileSettingsRow(
              icon: CupertinoIcons.person_crop_circle,
              label: 'Account',
              onTap: () => onRowTap('Account'),
            ),
            ProfileSettingsRow(
              icon: CupertinoIcons.lock,
              label: 'Privacy',
              onTap: () => onRowTap('Privacy'),
            ),
            ProfileSettingsRow(
              icon: CupertinoIcons.question_circle,
              label: 'Help & feedback',
              onTap: () => onRowTap('Help & feedback'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            ProfileSettingsRow(
              icon: CupertinoIcons.square_arrow_right,
              label: 'Sign out',
              tint: AppColors.error,
              showChevron: false,
              onTap: isSigningOut ? null : onSignOut,
              trailing: isSigningOut
                  ? const CupertinoActivityIndicator(radius: 9)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.only(left: 52),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: AppColors.divider),
                ),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// A single settings row: leading icon, label, and either a chevron or a
/// caller-supplied trailing control.
class ProfileSettingsRow extends StatelessWidget {
  const ProfileSettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.tint,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.textPrimary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: color),
            ),
          ),
          ?trailing,
          if (trailing == null && showChevron && onTap != null)
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: row,
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        minimumSize: const Size(double.infinity, 52),
        padding: EdgeInsets.zero,
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap!.call();
        },
        child: row,
      ),
    );
  }
}
