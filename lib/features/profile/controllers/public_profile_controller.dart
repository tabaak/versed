import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fits/models/fit.dart';
import '../../fits/services/fit_service.dart';
import '../models/profile_model.dart';
import '../models/public_profile.dart';
import '../services/profile_service.dart';

/// Another user's profile, keyed by their id.
///
/// A plain family rather than a controller: nothing on a public profile is
/// editable, so there is no state to hold past the three reads. Auto-disposed
/// because a profile is typically visited once on the way past a fit, and
/// every handle tapped this session staying resident would be a leak with no
/// reader.
///
/// Throws [ProfileNotFoundException] when there is no such profile to show.
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>((ref, userId) async {
      final profiles = ref.watch(profileServiceProvider);
      final fits = ref.watch(fitServiceProvider);

      final results = await Future.wait([
        profiles.fetchProfileById(userId),
        profiles.fetchStats(userId),
        fits.fetchOwnedBy(userId),
      ]);

      final profile = results[0] as Profile?;
      if (profile == null) throw ProfileNotFoundException(userId);

      return PublicProfile(
        profile: profile,
        stats: results[1] as ProfileStats,
        // The fits query reads the fits table alone, so its rows come back
        // with no owner columns on them. Whose they are is already in hand, so
        // stamp it on: a viewer opened from this grid can then name the owner
        // without a second round trip.
        fits: [
          for (final fit in results[2] as List<Fit>)
            fit.copyWith(
              ownerUsername: profile.username,
              ownerDisplayName: profile.displayName,
            ),
        ],
      );
    });
