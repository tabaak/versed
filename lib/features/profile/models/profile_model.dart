/// The application-facing profile row backing `public.profiles`.
///
/// [username] is nullable by design: Google sign-in provides no handle, so a
/// freshly created profile has none until the user picks one.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
  });

  static final Profile empty = Profile(
    id: '',
    username: null,
    displayName: null,
    avatarUrl: null,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  /// True until the user has completed the pick-a-handle step.
  bool get needsUsername => username == null || username!.isEmpty;

  /// `@handle`, or null while the profile still has no username.
  String? get handle => needsUsername ? null : '@$username';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Profile &&
            other.id == id &&
            other.username == username &&
            other.displayName == displayName &&
            other.avatarUrl == avatarUrl &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, username, displayName, avatarUrl, createdAt);

  @override
  String toString() {
    return 'Profile(id: $id, username: $username, '
        'displayName: $displayName, avatarUrl: $avatarUrl, '
        'createdAt: $createdAt)';
  }
}

/// Battle record shown in the profile stats row, as returned by the
/// `profile_stats()` database function.
class ProfileStats {
  const ProfileStats({
    required this.wins,
    required this.losses,
    required this.currentStreak,
  });

  static const ProfileStats empty = ProfileStats(
    wins: 0,
    losses: 0,
    currentStreak: 0,
  );

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
    );
  }

  final int wins;
  final int losses;

  /// Consecutive wins across the user's fits, reset by the first loss.
  final int currentStreak;

  int get battles => wins + losses;

  /// Win percentage rounded to a whole number; 0 before the first battle.
  int get winRate => battles == 0 ? 0 : (wins * 100 / battles).round();

  Map<String, dynamic> toJson() {
    return {'wins': wins, 'losses': losses, 'current_streak': currentStreak};
  }

  ProfileStats copyWith({int? wins, int? losses, int? currentStreak}) {
    return ProfileStats(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileStats &&
            other.wins == wins &&
            other.losses == losses &&
            other.currentStreak == currentStreak;
  }

  @override
  int get hashCode => Object.hash(wins, losses, currentStreak);

  @override
  String toString() {
    return 'ProfileStats(wins: $wins, losses: $losses, '
        'currentStreak: $currentStreak)';
  }
}

/// Identity plus battle record — the two halves of the profile tab that come
/// from the `profiles` table and `profile_stats()` respectively. The fits grid
/// is served separately by `myFitsControllerProvider`.
class ProfileSummary {
  const ProfileSummary({required this.profile, required this.stats});

  final Profile profile;
  final ProfileStats stats;

  ProfileSummary copyWith({Profile? profile, ProfileStats? stats}) {
    return ProfileSummary(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProfileSummary &&
            other.profile == profile &&
            other.stats == stats;
  }

  @override
  int get hashCode => Object.hash(profile, stats);

  @override
  String toString() => 'ProfileSummary(profile: $profile, stats: $stats)';
}
