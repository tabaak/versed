import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../../../core/utils/validators.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

/// The signed-in user's profile row and battle record. Null while signed out.
class ProfileController extends AsyncNotifier<ProfileSummary?> {
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
