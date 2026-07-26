import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/fit.dart';
import '../services/fit_service.dart';

/// The fits the signed-in user has bookmarked, newest save first.
///
/// The whole list is held in memory rather than queried per fit, because the
/// arena needs to answer "is this one saved?" for the pair on screen without a
/// round trip. A personal bookmark list is small enough for that to be safe.
class SavedFitsController extends AsyncNotifier<List<Fit>> {
  @override
  Future<List<Fit>> build() async {
    // Rebuilds when the signed-in user changes; saves are private, so one
    // account must never see another's.
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const [];

    return ref.watch(fitServiceProvider).fetchSavedBy(user.id);
  }

  List<Fit> get _current => state.value ?? const [];

  bool isSaved(String fitId) => _current.any((fit) => fit.id == fitId);

  /// Saves [fit] if it is not saved yet, removes it if it is. The grid and the
  /// arena bookmark update immediately and roll back if the write fails.
  ///
  /// Returns null on success, or a message worth showing.
  Future<String?> toggleSave(Fit fit) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return 'Sign in again to continue.';

    final previous = _current;
    final wasSaved = isSaved(fit.id);

    state = AsyncData(
      wasSaved
          ? previous.where((item) => item.id != fit.id).toList()
          : [fit, ...previous],
    );

    try {
      final service = ref.read(fitServiceProvider);
      if (wasSaved) {
        await service.unsaveFit(userId: user.id, fitId: fit.id);
      } else {
        await service.saveFit(userId: user.id, fitId: fit.id);
      }
      return null;
    } catch (error) {
      state = AsyncData(previous);
      return describeError(error);
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final user = ref.read(authControllerProvider).value;
      if (user == null) return const <Fit>[];
      return ref.read(fitServiceProvider).fetchSavedBy(user.id);
    });
  }
}

final savedFitsControllerProvider =
    AsyncNotifierProvider<SavedFitsController, List<Fit>>(
      SavedFitsController.new,
    );

/// Whether a single fit is saved, for widgets that only care about one.
///
/// Watching this instead of the list keeps a bookmark button from rebuilding
/// every time some unrelated fit is saved.
final isFitSavedProvider = Provider.family<bool, String>((ref, fitId) {
  final saved = ref.watch(savedFitsControllerProvider).value ?? const <Fit>[];
  return saved.any((fit) => fit.id == fitId);
});
