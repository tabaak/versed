import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../models/fit.dart';
import '../models/fit_genre.dart';
import '../services/fit_service.dart';

/// The signed-in user's own fits, as shown in the profile grid.
class MyFitsController extends AsyncNotifier<List<Fit>> {
  @override
  Future<List<Fit>> build() async {
    // Rebuilds when the signed-in user changes, so one account never shows
    // another's fits.
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const [];

    return ref.watch(fitServiceProvider).fetchOwnedBy(user.id);
  }

  List<Fit> get _current => state.value ?? const [];

  /// Uploads a new fit and prepends it to the list. Throws on failure so the
  /// caller can surface the reason.
  Future<Fit> addFit({
    required Uint8List bytes,
    required String fileExtension,
    required FitGenre genre,
  }) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      throw StateError('Cannot upload a fit while signed out.');
    }

    final fit = await ref
        .read(fitServiceProvider)
        .createFit(
          ownerId: user.id,
          bytes: bytes,
          fileExtension: fileExtension,
          genre: genre,
        );

    state = AsyncData([fit, ..._current]);
    return fit;
  }

  /// Removes a fit from the grid immediately, restoring it if the write fails.
  Future<void> deleteFit(Fit fit) async {
    final previous = _current;
    state = AsyncData(previous.where((item) => item.id != fit.id).toList());

    try {
      await ref.read(fitServiceProvider).softDelete(fit);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final user = ref.read(authControllerProvider).value;
      if (user == null) return const <Fit>[];
      return ref.read(fitServiceProvider).fetchOwnedBy(user.id);
    });
  }
}

final myFitsControllerProvider =
    AsyncNotifierProvider<MyFitsController, List<Fit>>(MyFitsController.new);
