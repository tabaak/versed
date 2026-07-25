import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../fits/models/fit.dart';
import '../../fits/models/fit_genre.dart';
import '../models/matchup.dart';

class VersusService {
  VersusService(this._client);

  final SupabaseClient _client;

  /// Asks the database for the next pair this user has not judged yet.
  ///
  /// [genre] narrows the draw to one category; null lets the database pick,
  /// weighted by how many fits each genre holds.
  ///
  /// Returns null when the pool is exhausted: `next_matchup()` yields no rows
  /// once every available pairing has been voted on.
  Future<Matchup?> fetchNextMatchup({FitGenre? genre}) async {
    final rows = await _client.rpc<List<dynamic>>(
      'next_matchup',
      params: {'p_genre': genre?.value},
    );
    if (rows.length < 2) return null;

    final fits = rows
        .map((row) => Fit.fromJson(row as Map<String, dynamic>))
        .toList();

    return Matchup(left: fits.first, right: fits[1]);
  }

  /// Records the vote and moves both fits' counters in one transaction.
  ///
  /// Throws a [PostgrestException] the caller is expected to interpret:
  /// `23505` means this pair was already judged, `42501` means the voter owns
  /// one of the fits, `22023` means a fit went away mid-matchup.
  Future<void> castVote({
    required String winnerId,
    required String loserId,
  }) async {
    await _client.rpc(
      'cast_vote',
      params: {'p_winner_id': winnerId, 'p_loser_id': loserId},
    );
  }
}

final versusServiceProvider = Provider<VersusService>((ref) {
  return VersusService(ref.watch(supabaseClientProvider));
});
