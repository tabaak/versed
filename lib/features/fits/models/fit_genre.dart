/// The style a fit belongs to.
///
/// Mirrors the `fit_genre` enum in Postgres, and matchmaking depends on that:
/// `next_matchup()` draws both sides of a battle from one genre, so a fit's
/// genre decides who it can ever be compared against.
///
/// Order is display order — the upload picker renders them as declared.
/// Adding a genre means adding it here *and* in the database
/// (`alter type public.fit_genre add value '<value>';`).
enum FitGenre {
  streetwear('streetwear', 'Streetwear', 'Hoodies, sneakers, oversized fits'),
  formal('formal', 'Formal', 'Suits, tailoring, eveningwear'),
  casual('casual', 'Casual', 'Everyday jeans-and-tee'),
  y2k('y2k', 'Y2K', '2000s revival, low-rise, baby tees'),
  techwear('techwear', 'Techwear', 'Technical fabrics, utility, monochrome'),
  vintage('vintage', 'Vintage', 'Thrifted, decade-specific, retro');

  const FitGenre(this.value, this.label, this.description);

  /// The string stored in `fits.genre`.
  final String value;

  /// Shown in the upload picker and on the arena board.
  final String label;

  /// One-line hint under the label, so the picker is self-explanatory.
  final String description;

  /// The genre for a stored [value], or null when it is absent or unknown.
  ///
  /// An unknown value means the database has a genre this build predates.
  /// Returning null lets the UI omit the label rather than crash on a row it
  /// otherwise renders perfectly well.
  static FitGenre? fromValue(String? value) {
    if (value == null) return null;
    for (final genre in FitGenre.values) {
      if (genre.value == value) return genre;
    }
    return null;
  }
}
