import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/models/auth_model.dart';
import '../../models/profile_model.dart';

/// Avatar, name and handle block at the top of the profile tab.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.user,
    required this.profile,
    required this.onEditProfile,
    super.key,
  });

  final AuthModel? user;
  final ProfileModel profile;
  final VoidCallback onEditProfile;

  String get _name => user?.displayName ?? user?.email ?? 'Anonymous';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(url: user?.avatarUrl, name: _name),
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
                    profile.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.secondaryBody,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.joinedLabel,
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  static const _size = 72.0;

  final String? url;
  final String name;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.elevatedSurface,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? Text(
              _initial,
              style: AppTextStyles.monogram.copyWith(
                color: AppColors.textPrimary,
                fontSize: 28,
              ),
            )
          : Image.network(
              url!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(
                _initial,
                style: AppTextStyles.monogram.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                ),
              ),
            ),
    );
  }
}
