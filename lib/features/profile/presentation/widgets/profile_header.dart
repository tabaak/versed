import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/models/auth_model.dart';
import '../../models/profile_model.dart';
import 'profile_avatar.dart';

/// Avatar, name and handle block at the top of the profile tab.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.user,
    required this.profile,
    required this.onEditProfile,
    super.key,
  });

  final AuthModel? user;
  final Profile profile;
  final VoidCallback onEditProfile;

  /// The profile row wins over the auth metadata: it is what the rest of the
  /// app reads, and it is the copy the user can eventually edit.
  String get _name =>
      profile.displayName ?? user?.displayName ?? user?.email ?? 'Anonymous';

  /// Only the profile row's photo: the auth metadata is not a fallback, or
  /// removing an uploaded avatar would silently resurrect the Google one. The
  /// sign-up trigger copies Google's avatar into the row anyway.
  String? get _avatarUrl => profile.avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProfileAvatar(url: _avatarUrl, name: _name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.handle ?? 'No handle yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.secondaryBody,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    joinedLabel(profile.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Edit profile',
          variant: AppButtonVariant.secondary,
          onPressed: onEditProfile,
        ),
      ],
    );
  }
}
