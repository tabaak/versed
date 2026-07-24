import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_model.dart';

/// Placeholder profile data. Swap this provider's body for a Supabase query
/// once the fits and battles tables exist; the UI reads it as-is.
final profileProvider = Provider<ProfileModel>((ref) {
  return const ProfileModel(
    handle: '@fitcheck',
    joinedLabel: 'Joined July 2026',
    stats: ProfileStats(wins: 128, losses: 74, currentStreak: 6),
    fits: [
      ProfileFit(
        id: 'fit-1',
        asset: 'assets/auth/outfit1.png',
        wins: 42,
        battles: 61,
      ),
      ProfileFit(
        id: 'fit-2',
        asset: 'assets/auth/outfit2.png',
        wins: 31,
        battles: 55,
      ),
      ProfileFit(
        id: 'fit-3',
        asset: 'assets/auth/outfit3.jpg',
        wins: 27,
        battles: 38,
      ),
      ProfileFit(
        id: 'fit-4',
        asset: 'assets/auth/outfit4.jpg',
        wins: 18,
        battles: 29,
      ),
      ProfileFit(
        id: 'fit-5',
        asset: 'assets/auth/outfit5.jpg',
        wins: 7,
        battles: 12,
      ),
      ProfileFit(
        id: 'fit-6',
        asset: 'assets/auth/outfit6.jpg',
        wins: 3,
        battles: 7,
      ),
    ],
  );
});
