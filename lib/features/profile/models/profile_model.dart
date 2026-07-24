/// Battle record shown in the profile stats row.
class ProfileStats {
  const ProfileStats({
    required this.wins,
    required this.losses,
    required this.currentStreak,
  });

  final int wins;
  final int losses;
  final int currentStreak;

  int get battles => wins + losses;

  /// Win percentage rounded to a whole number; 0 before the first battle.
  int get winRate => battles == 0 ? 0 : (wins * 100 / battles).round();
}

/// A single outfit the user has put into the arena.
class ProfileFit {
  const ProfileFit({
    required this.id,
    required this.asset,
    required this.wins,
    required this.battles,
  });

  final String id;
  final String asset;
  final int wins;
  final int battles;
}

/// Everything the profile tab renders outside of the signed-in auth user.
class ProfileModel {
  const ProfileModel({
    required this.handle,
    required this.joinedLabel,
    required this.stats,
    required this.fits,
  });

  final String handle;
  final String joinedLabel;
  final ProfileStats stats;
  final List<ProfileFit> fits;
}
