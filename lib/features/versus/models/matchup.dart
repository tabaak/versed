import '../../fits/models/fit.dart';
import '../../fits/models/fit_genre.dart';

/// Which side of the board a fit is on.
enum VersusSide { left, right }

/// Two fits pitted against each other. Matchups are ephemeral: nothing is
/// stored until the user votes.
class Matchup {
  const Matchup({required this.left, required this.right});

  static const Matchup empty = Matchup(left: Fit.empty, right: Fit.empty);

  final Fit left;
  final Fit right;

  /// The genre both fits were drawn from — `next_matchup()` only ever pairs
  /// like with like. Null when neither row carried a genre this build knows.
  FitGenre? get genre => left.genre ?? right.genre;

  Fit fitOn(VersusSide side) => side == VersusSide.left ? left : right;

  Fit opponentOf(VersusSide side) => side == VersusSide.left ? right : left;

  /// Order-independent identity for the pair, so the same two fits are
  /// recognised whichever side each one landed on. Mirrors the normalised
  /// `(fit_a_id, fit_b_id)` key the votes table is unique on.
  String get pairKey {
    final ids = [left.id, right.id]..sort();
    return ids.join(':');
  }

  Matchup copyWith({Fit? left, Fit? right}) {
    return Matchup(left: left ?? this.left, right: right ?? this.right);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Matchup && other.left == left && other.right == right;
  }

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'Matchup(left: ${left.id}, right: ${right.id})';
}

/// What the arena screen renders.
class VersusState {
  const VersusState({this.current, this.upcoming});

  static const VersusState empty = VersusState();

  /// The matchup on screen. Null once the user has judged everything
  /// available to them.
  final Matchup? current;

  /// The matchup queued behind [current], exposed so the screen can precache
  /// its images while the user is still deciding.
  final Matchup? upcoming;

  bool get isExhausted => current == null;

  VersusState copyWith({Matchup? current, Matchup? upcoming}) {
    return VersusState(
      current: current ?? this.current,
      upcoming: upcoming ?? this.upcoming,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VersusState &&
            other.current == current &&
            other.upcoming == upcoming;
  }

  @override
  int get hashCode => Object.hash(current, upcoming);

  @override
  String toString() => 'VersusState(current: $current, upcoming: $upcoming)';
}
