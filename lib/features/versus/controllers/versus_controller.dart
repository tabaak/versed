import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_messages.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../fits/models/fit.dart';
import '../../fits/models/fit_genre.dart';
import '../../fits/services/fit_service.dart';
import '../models/matchup.dart';
import '../services/versus_service.dart';
import 'arena_filter_controller.dart';

/// Drives the arena: keeps a small queue of matchups so a vote is followed by
/// the next pair instantly instead of a network round trip.
class VersusController extends AsyncNotifier<VersusState> {
  /// How many matchups to keep queued behind the one on screen.
  static const _queueTarget = 3;

  /// A small pool can hand back pairs the queue already holds. Cap the calls
  /// so refilling always terminates instead of spinning on duplicates.
  static const _maxFetchAttempts = 6;

  final _queue = <Matchup>[];

  /// Pairs already queued or shown this session. The database only excludes a
  /// pair once its vote is recorded, so prefetching can legitimately return a
  /// pair that is already in hand.
  final _seenPairKeys = <String>{};

  /// The category this queue was filled from; null draws from all of them.
  FitGenre? _genre;

  @override
  Future<VersusState> build() async {
    // Rebuild for a different signed-in user; their exclusions differ.
    ref.watch(authControllerProvider);
    // ...and for a different category: everything queued belongs to the genre
    // that was selected when it was fetched.
    _genre = ref.watch(arenaFilterControllerProvider);

    _queue.clear();
    _seenPairKeys.clear();

    await _fillQueue();
    return _takeNext();
  }

  /// Records a vote. Returns null on success, or a message worth showing.
  ///
  /// A duplicate is reported as success: the vote it collides with is already
  /// counted, and the user has no way to act on the distinction.
  ///
  /// The on-screen pair is updated before the call goes out, so the winner's
  /// crown and streak move with the reveal animation instead of a network
  /// round trip later. Nothing rolls the patch back on failure: the pair is
  /// replaced by [advance] either way, and the one error that is not a real
  /// failure — a duplicate — did count the vote.
  Future<String?> submitVote({
    required String winnerId,
    required String loserId,
  }) async {
    _applyOutcome(winnerId);

    try {
      await ref
          .read(versusServiceProvider)
          .castVote(winnerId: winnerId, loserId: loserId);
      return null;
    } on PostgrestException catch (error) {
      if (error.code == '23505') return null;
      return describeError(error);
    } catch (error) {
      return describeError(error);
    }
  }

  /// Moves to the next matchup, fetching more if the queue has run dry.
  Future<void> advance() async {
    if (_queue.isNotEmpty) {
      state = AsyncData(_takeNext());
      unawaited(_topUp());
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _fillQueue();
      return _takeNext();
    });
  }

  /// Flags the fit currently on screen. Returns null on success, or a message
  /// worth showing. The fit stays on screen: pulling it mid-matchup would
  /// leave the board half empty, and it only leaves the pool once enough
  /// people agree.
  Future<String?> reportFit({
    required String fitId,
    required FitReportReason reason,
  }) async {
    try {
      await ref.read(fitServiceProvider).report(fitId: fitId, reason: reason);
      return null;
    } catch (error) {
      return describeError(error);
    }
  }

  /// Re-runs [build] from scratch — used by the retry and refresh actions.
  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// Moves the current pair's counters as if the vote had already landed.
  void _applyOutcome(String winnerId) {
    final current = state.value?.current;
    if (current == null) return;

    final settled = current.withOutcome(winnerId);
    if (settled == current) return;

    state = AsyncData(
      VersusState(current: settled, upcoming: state.value?.upcoming),
    );
  }

  VersusState _takeNext() {
    final current = _queue.isEmpty ? null : _queue.removeAt(0);
    return VersusState(
      current: current,
      upcoming: _queue.isEmpty ? null : _queue.first,
    );
  }

  Future<void> _fillQueue() async {
    final service = ref.read(versusServiceProvider);
    var attempts = 0;

    while (_queue.length < _queueTarget && attempts < _maxFetchAttempts) {
      attempts++;
      final matchup = await service.fetchNextMatchup(genre: _genre);
      if (matchup == null) break;
      if (_seenPairKeys.add(matchup.pairKey)) {
        _queue.add(matchup);
      }
    }
  }

  /// Background refill. A failure here is not worth interrupting the user —
  /// the queue simply drains and [advance] surfaces the problem then.
  Future<void> _topUp() async {
    try {
      await _fillQueue();
    } catch (_) {
      return;
    }

    final current = state.value?.current;
    if (current == null || _queue.isEmpty) return;

    state = AsyncData(VersusState(current: current, upcoming: _queue.first));
  }
}

final versusControllerProvider =
    AsyncNotifierProvider<VersusController, VersusState>(VersusController.new);
