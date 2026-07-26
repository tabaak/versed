import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:versed/features/auth/controllers/auth_controller.dart';
import 'package:versed/features/auth/models/auth_model.dart';
import 'package:versed/features/fits/controllers/saved_fits_controller.dart';
import 'package:versed/features/fits/models/fit.dart';
import 'package:versed/features/fits/services/fit_service.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthModel?> build() async => const AuthModel(
    id: 'user-1',
    email: 'ada@example.com',
    displayName: 'Ada Lovelace',
    avatarUrl: null,
  );
}

class _SignedOutAuthController extends AuthController {
  @override
  Future<AuthModel?> build() async => null;
}

/// Stands in for Supabase: records the writes, and can be told to fail one.
class _FakeFitService implements FitService {
  _FakeFitService({this.saved = const [], this.error});

  final List<Fit> saved;

  /// Thrown by [saveFit] and [unsaveFit], to exercise the rollback.
  final Object? error;

  final List<String> savedIds = [];
  final List<String> unsavedIds = [];

  @override
  Future<List<Fit>> fetchSavedBy(String userId) async => saved;

  @override
  Future<void> saveFit({required String userId, required String fitId}) async {
    if (error != null) throw error!;
    savedIds.add(fitId);
  }

  @override
  Future<void> unsaveFit({
    required String userId,
    required String fitId,
  }) async {
    if (error != null) throw error!;
    unsavedIds.add(fitId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Fit _fit(String id) => Fit.empty.copyWith(id: id, ownerId: 'someone-else');

/// A container with the saved list loaded, as the profile tab would have it.
///
/// The listener stands in for the widget that normally watches the provider:
/// without one the initial load never settles.
Future<ProviderContainer> _loadedContainer(
  _FakeFitService service, {
  bool signedIn = true,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      authControllerProvider.overrideWith(
        signedIn ? _FakeAuthController.new : _SignedOutAuthController.new,
      ),
      fitServiceProvider.overrideWithValue(service),
    ],
  );

  container.listen(savedFitsControllerProvider, (_, _) {});
  await pumpEventQueue();

  return container;
}

void main() {
  test('loads the saved fits of the signed-in user', () async {
    final service = _FakeFitService(saved: [_fit('fit-1'), _fit('fit-2')]);
    final container = await _loadedContainer(service);

    final fits = container.read(savedFitsControllerProvider).value;

    expect(fits!.map((fit) => fit.id), ['fit-1', 'fit-2']);
    expect(
      container.read(savedFitsControllerProvider.notifier).isSaved('fit-1'),
      isTrue,
    );
    expect(container.read(isFitSavedProvider('fit-9')), isFalse);
  });

  test('saving puts the fit at the front of the list', () async {
    final service = _FakeFitService(saved: [_fit('fit-1')]);
    final container = await _loadedContainer(service);

    final notifier = container.read(savedFitsControllerProvider.notifier);
    final failure = await notifier.toggleSave(_fit('fit-2'));

    expect(failure, isNull);
    expect(service.savedIds, ['fit-2']);
    expect(
      container.read(savedFitsControllerProvider).value!.map((f) => f.id),
      ['fit-2', 'fit-1'],
    );
  });

  test('saving a fit that is already saved removes it', () async {
    final service = _FakeFitService(saved: [_fit('fit-1')]);
    final container = await _loadedContainer(service);

    final notifier = container.read(savedFitsControllerProvider.notifier);
    final failure = await notifier.toggleSave(_fit('fit-1'));

    expect(failure, isNull);
    expect(service.unsavedIds, ['fit-1']);
    expect(container.read(savedFitsControllerProvider).value, isEmpty);
    expect(notifier.isSaved('fit-1'), isFalse);
  });

  test('a failed write rolls the list back and reports why', () async {
    final service = _FakeFitService(
      saved: [_fit('fit-1')],
      error: Exception('offline'),
    );
    final container = await _loadedContainer(service);

    final notifier = container.read(savedFitsControllerProvider.notifier);
    final failure = await notifier.toggleSave(_fit('fit-2'));

    expect(failure, isNotNull);
    expect(
      container.read(savedFitsControllerProvider).value!.map((f) => f.id),
      ['fit-1'],
    );
  });

  test('a signed-out user has no saves and cannot write', () async {
    final service = _FakeFitService(saved: [_fit('fit-1')]);
    final container = await _loadedContainer(service, signedIn: false);

    expect(container.read(savedFitsControllerProvider).value, isEmpty);

    final failure = await container
        .read(savedFitsControllerProvider.notifier)
        .toggleSave(_fit('fit-2'));

    expect(failure, isNotNull);
    expect(service.savedIds, isEmpty);
  });
}
