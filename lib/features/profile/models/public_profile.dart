import 'package:flutter/foundation.dart';

import '../../fits/models/fit.dart';
import 'profile_model.dart';

/// Someone else's profile, as the public view shows it: who they are, their
/// battle record, and the fits of theirs still standing in the arena.
///
/// [ProfileSummary] carries the same first two halves for the signed-in user
/// but leaves the fits to `myFitsControllerProvider`. A profile you are only
/// visiting has no such controller behind it, so its fits travel with it.
class PublicProfile {
  const PublicProfile({
    required this.profile,
    required this.stats,
    required this.fits,
  });

  static final PublicProfile empty = PublicProfile(
    profile: Profile.empty,
    stats: ProfileStats.empty,
    fits: const [],
  );

  final Profile profile;
  final ProfileStats stats;

  /// Live fits only, newest first — the same set the owner sees in their own
  /// grid, minus anything they have retired.
  final List<Fit> fits;

  PublicProfile copyWith({
    Profile? profile,
    ProfileStats? stats,
    List<Fit>? fits,
  }) {
    return PublicProfile(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      fits: fits ?? this.fits,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PublicProfile &&
            other.profile == profile &&
            other.stats == stats &&
            listEquals(other.fits, fits);
  }

  @override
  int get hashCode => Object.hash(profile, stats, Object.hashAll(fits));

  @override
  String toString() {
    return 'PublicProfile(profile: $profile, stats: $stats, '
        'fits: ${fits.length})';
  }
}

/// Thrown when a profile cannot be read: the account was deleted, or the row
/// is one row-level security will not hand over.
///
/// A missing profile is an expected outcome rather than a failure, so the view
/// tells it apart from a network error and says so plainly.
class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException(this.userId);

  final String userId;

  @override
  String toString() => 'ProfileNotFoundException($userId)';
}
