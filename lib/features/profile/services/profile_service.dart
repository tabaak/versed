import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/profile_model.dart';

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';
  static const _columns = 'id, username, display_name, avatar_url, created_at';

  /// Reads a profile, creating the row if it is somehow missing.
  ///
  /// The `on_auth_user_created` trigger normally creates it at sign-up; the
  /// insert here covers accounts that predate the trigger.
  Future<Profile> fetchProfile(String id) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', id)
        .maybeSingle();

    if (row != null) return Profile.fromJson(row);

    final created = await _client
        .from(_table)
        .insert({'id': id})
        .select(_columns)
        .single();

    return Profile.fromJson(created);
  }

  Future<ProfileStats> fetchStats(String id) async {
    final rows = await _client.rpc<List<dynamic>>(
      'profile_stats',
      params: {'p_profile_id': id},
    );

    if (rows.isEmpty) return ProfileStats.empty;
    return ProfileStats.fromJson(rows.first as Map<String, dynamic>);
  }

  /// Best-effort check used to warn before submitting. The unique index is
  /// the real authority — a handle can be taken between this call and the
  /// update.
  Future<bool> isUsernameAvailable(String username) async {
    final row = await _client
        .from(_table)
        .select('id')
        .eq('username', username)
        .maybeSingle();

    return row == null;
  }

  /// Claims a handle. Throws a [PostgrestException] with code `23505` when
  /// another user got there first.
  Future<Profile> setUsername({
    required String id,
    required String username,
  }) async {
    final row = await _client
        .from(_table)
        .update({'username': username})
        .eq('id', id)
        .select(_columns)
        .single();

    return Profile.fromJson(row);
  }

  /// Saves the editable identity fields in one write. A null [displayName]
  /// clears the column, which sends the profile back to its handle.
  ///
  /// Throws a [PostgrestException] with code `23505` when the handle was
  /// claimed by someone else first.
  Future<Profile> updateProfile({
    required String id,
    required String username,
    required String? displayName,
  }) async {
    final row = await _client
        .from(_table)
        .update({'username': username, 'display_name': displayName})
        .eq('id', id)
        .select(_columns)
        .single();

    return Profile.fromJson(row);
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(supabaseClientProvider));
});
