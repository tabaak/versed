/// A single outfit entered into the arena.
///
/// The same class covers two row shapes, because the arena and the profile
/// read fits through different queries:
///
/// * `next_matchup()` returns `fit_id` plus the owner's handle, but no
///   `created_at` — the arena never dates a fit.
/// * the `fits` table returns `id` and `created_at`, but no owner columns —
///   the profile grid already knows whose fits it is showing.
///
/// Fields the active query does not provide stay null.
class Fit {
  const Fit({
    required this.id,
    required this.ownerId,
    required this.imagePath,
    required this.wins,
    required this.losses,
    this.createdAt,
    this.ownerUsername,
    this.ownerDisplayName,
  });

  static const Fit empty = Fit(
    id: '',
    ownerId: '',
    imagePath: '',
    wins: 0,
    losses: 0,
  );

  factory Fit.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'] as String?;

    return Fit(
      // `next_matchup()` names the column fit_id; the table names it id.
      id: (json['id'] ?? json['fit_id']) as String,
      ownerId: json['owner_id'] as String,
      imagePath: json['image_path'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
      ownerUsername: json['username'] as String?,
      ownerDisplayName: json['display_name'] as String?,
    );
  }

  final String id;
  final String ownerId;
  final String imagePath;
  final int wins;
  final int losses;
  final DateTime? createdAt;
  final String? ownerUsername;
  final String? ownerDisplayName;

  int get battles => wins + losses;

  /// Win percentage rounded to a whole number; 0 before the first battle.
  int get winRate => battles == 0 ? 0 : (wins * 100 / battles).round();

  /// `@handle` when the query provided one, otherwise null.
  String? get ownerHandle => ownerUsername == null ? null : '@$ownerUsername';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'image_path': imagePath,
      'wins': wins,
      'losses': losses,
      'created_at': createdAt?.toIso8601String(),
      'username': ownerUsername,
      'display_name': ownerDisplayName,
    };
  }

  Fit copyWith({
    String? id,
    String? ownerId,
    String? imagePath,
    int? wins,
    int? losses,
    DateTime? createdAt,
    String? ownerUsername,
    String? ownerDisplayName,
  }) {
    return Fit(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      imagePath: imagePath ?? this.imagePath,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      createdAt: createdAt ?? this.createdAt,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Fit &&
            other.id == id &&
            other.ownerId == ownerId &&
            other.imagePath == imagePath &&
            other.wins == wins &&
            other.losses == losses &&
            other.createdAt == createdAt &&
            other.ownerUsername == ownerUsername &&
            other.ownerDisplayName == ownerDisplayName;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      ownerId,
      imagePath,
      wins,
      losses,
      createdAt,
      ownerUsername,
      ownerDisplayName,
    );
  }

  @override
  String toString() {
    return 'Fit(id: $id, ownerId: $ownerId, imagePath: $imagePath, '
        'wins: $wins, losses: $losses, createdAt: $createdAt, '
        'ownerUsername: $ownerUsername, ownerDisplayName: $ownerDisplayName)';
  }
}

/// The reasons `report_fit()` accepts, with their user-facing labels.
enum FitReportReason {
  inappropriate('inappropriate', 'Inappropriate'),
  notAnOutfit('not_an_outfit', 'Not an outfit'),
  spam('spam', 'Spam'),
  other('other', 'Something else');

  const FitReportReason(this.value, this.label);

  /// The string stored in `fit_reports.reason`.
  final String value;
  final String label;
}
