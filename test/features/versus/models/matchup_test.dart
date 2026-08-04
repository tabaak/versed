import 'package:flutter_test/flutter_test.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/versus/models/matchup.dart';

Fit _fit(
  String id, {
  int wins = 0,
  int losses = 0,
  int streak = 0,
  int best = 0,
}) {
  return Fit(
    id: id,
    ownerId: 'owner-$id',
    imagePath: '$id.jpg',
    wins: wins,
    losses: losses,
    currentStreak: streak,
    bestStreak: best,
  );
}

void main() {
  group('Matchup.withOutcome', () {
    test('extends the winner\'s run and ends the loser\'s', () {
      final matchup = Matchup(
        left: _fit('a', wins: 5, streak: 2, best: 4),
        right: _fit('b', losses: 1, streak: 3, best: 3),
      );

      final settled = matchup.withOutcome('a');

      expect(settled.left.wins, 6);
      expect(settled.left.currentStreak, 3);
      expect(settled.right.losses, 2);
      expect(settled.right.currentStreak, 0);
    });

    test('leaves a best streak alone until the run passes it', () {
      final matchup = Matchup(
        left: _fit('a', streak: 1, best: 6),
        right: _fit('b'),
      );

      expect(matchup.withOutcome('a').left.bestStreak, 6);
    });

    test('raises the best streak once the run beats it', () {
      final matchup = Matchup(
        left: _fit('a', streak: 6, best: 6),
        right: _fit('b'),
      );

      expect(matchup.withOutcome('a').left.bestStreak, 7);
    });

    test('a loss never takes the best streak back', () {
      final matchup = Matchup(
        left: _fit('a'),
        right: _fit('b', streak: 4, best: 4),
      );

      final settled = matchup.withOutcome('a');

      expect(settled.right.currentStreak, 0);
      expect(settled.right.bestStreak, 4);
    });

    test('a winner from another pair books nothing against either fit', () {
      final matchup = Matchup(left: _fit('a'), right: _fit('b'));

      expect(matchup.withOutcome('c'), matchup);
    });

    test('mirrors cast_vote closely enough to survive a second round', () {
      // Two votes without a refetch in between: the arena patches the same
      // matchup twice only if the user somehow votes again, but the arithmetic
      // has to compose either way.
      final matchup = Matchup(left: _fit('a'), right: _fit('b'));

      final twice = matchup.withOutcome('a').withOutcome('a');

      expect(twice.left.wins, 2);
      expect(twice.left.currentStreak, 2);
      expect(twice.left.bestStreak, 2);
      expect(twice.left.isOnStreak, isTrue);
    });
  });
}
