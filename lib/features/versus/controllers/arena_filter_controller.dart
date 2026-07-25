import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fits/models/fit_genre.dart';

/// Which category the arena is drawing matchups from.
///
/// Null means "All": the database picks a genre per matchup, weighted by how
/// many fits each one holds. Kept apart from [VersusController] because the
/// controller *watches* it — the queue it holds is only valid for one filter,
/// so changing this has to rebuild the controller from scratch.
class ArenaFilterController extends Notifier<FitGenre?> {
  @override
  FitGenre? build() => null;

  /// Switches the arena to [genre], or back to every genre when null.
  void select(FitGenre? genre) => state = genre;
}

final arenaFilterControllerProvider =
    NotifierProvider<ArenaFilterController, FitGenre?>(
      ArenaFilterController.new,
    );
