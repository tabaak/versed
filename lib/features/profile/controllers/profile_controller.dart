import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../upload/models/upload_state.dart';
import '../../upload/services/image_crop_service.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

/// The signed-in user's profile row and battle record. Null while signed out.
class ProfileController extends AsyncNotifier<ProfileSummary?> {
  /// Avatars are never rendered above 72pt, so anything past this is bytes
  /// nobody sees — and the bucket's 5 MB cap is generous for it.
  static const _avatarSize = 512;

  @override
  Future<ProfileSummary?> build() async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return null;

    return _load(user.id);
  }

  /// Claims a handle. Returns null on success, or the reason it failed.
  Future<String?> chooseUsername(String username) async {
    final normalized = username.trim().toLowerCase();

    final invalid = usernameError(normalized);
    if (invalid != null) return invalid;

    final user = ref.read(authControllerProvider).value;
    if (user == null) return 'Sign in again to continue.';

    final summary = state.value;

    try {
      final profile = await ref
          .read(profileServiceProvider)
          .setUsername(id: user.id, username: normalized);

      state = AsyncData(
        summary == null
            ? ProfileSummary(profile: profile, stats: ProfileStats.empty)
            : summary.copyWith(profile: profile),
      );
      return null;
    } on PostgrestException catch (error) {
      // The unique index rejected it between the availability check and here.
      if (error.code == '23505') return 'That handle is taken.';
      return describeError(error);
    } catch (error) {
      return describeError(error);
    }
  }

  /// Saves the profile edits. Returns null on success, or the reason it
  /// failed.
  ///
  /// [avatar] replaces the profile photo and [removeAvatar] clears it; with
  /// neither, whatever the profile already has survives the save.
  ///
  /// [avatarCrop] is the square region of [avatar] the user framed, in source
  /// pixels; without one the photo is cropped from its centre.
  Future<String?> updateProfile({
    required String username,
    required String? displayName,
    PickedFit? avatar,
    Rect? avatarCrop,
    bool removeAvatar = false,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final trimmedName = displayName?.trim();
    // An empty field means "no display name", not an empty one.
    final normalizedName = (trimmedName == null || trimmedName.isEmpty)
        ? null
        : trimmedName;

    final invalid =
        usernameError(normalizedUsername) ?? displayNameError(normalizedName);
    if (invalid != null) return invalid;

    final user = ref.read(authControllerProvider).value;
    if (user == null) return 'Sign in again to continue.';

    final summary = state.value;
    final service = ref.read(profileServiceProvider);
    final previousAvatarUrl = summary?.profile.avatarUrl;

    // Uploaded before the row is written, so the profile never points at a
    // file that does not exist. Cleaned up below if the write fails.
    String? uploadedAvatarUrl;

    try {
      if (avatar != null) {
        final square = await ref
            .read(imageCropServiceProvider)
            .crop(
              source: avatar,
              crop: avatarCrop ?? avatar.centeredSquareCrop,
              maxDimension: _avatarSize,
            );

        uploadedAvatarUrl = await service.uploadAvatar(
          ownerId: user.id,
          bytes: square.bytes,
          fileExtension: square.fileExtension,
        );
      }

      final avatarUrl = switch (avatar) {
        null when removeAvatar => null,
        null => previousAvatarUrl,
        _ => uploadedAvatarUrl,
      };

      final profile = await service.updateProfile(
        id: user.id,
        username: normalizedUsername,
        displayName: normalizedName,
        avatarUrl: avatarUrl,
      );

      state = AsyncData(
        summary == null
            ? ProfileSummary(profile: profile, stats: ProfileStats.empty)
            : summary.copyWith(profile: profile),
      );

      // The old photo is only unreachable once the row stopped pointing at it.
      if (avatarUrl != previousAvatarUrl) {
        await service.removeAvatar(previousAvatarUrl).catchError((_) {});
      }
      return null;
    } on PostgrestException catch (error) {
      await _discardUpload(service, uploadedAvatarUrl);
      if (error.code == '23505') return 'That handle is taken.';
      return describeError(error);
    } catch (error) {
      await _discardUpload(service, uploadedAvatarUrl);
      return describeError(error);
    }
  }

  /// Removes an avatar that was uploaded for a save that then failed, so a
  /// rejected handle does not leave a file behind.
  Future<void> _discardUpload(ProfileService service, String? url) async {
    if (url == null) return;
    await service.removeAvatar(url).catchError((_) {});
  }

  Future<bool> isUsernameAvailable(String username) {
    return ref
        .read(profileServiceProvider)
        .isUsernameAvailable(username.trim().toLowerCase());
  }

  Future<void> refresh() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }

    state = await AsyncValue.guard(() => _load(user.id));
  }

  Future<ProfileSummary> _load(String userId) async {
    final service = ref.read(profileServiceProvider);
    final results = await Future.wait([
      service.fetchProfile(userId),
      service.fetchStats(userId),
    ]);

    return ProfileSummary(
      profile: results[0] as Profile,
      stats: results[1] as ProfileStats,
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileSummary?>(
      ProfileController.new,
    );
