import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:versed/features/auth/controllers/auth_controller.dart';
import 'package:versed/features/auth/models/auth_model.dart';
import 'package:versed/features/profile/controllers/profile_controller.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/services/profile_service.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthModel?> build() async => const AuthModel(
    id: 'user-1',
    email: 'ada@example.com',
    displayName: 'Ada Lovelace',
    avatarUrl: null,
  );
}

class _FakeProfileService implements ProfileService {
  _FakeProfileService({this.error});

  /// Thrown instead of writing, to exercise the failure paths.
  final Object? error;

  String? username;
  String? displayName;

  @override
  Future<Profile> fetchProfile(String id) async => Profile.empty.copyWith(
    id: id,
    username: 'ada',
    displayName: 'Ada Lovelace',
  );

  @override
  Future<ProfileStats> fetchStats(String id) async => ProfileStats.empty;

  @override
  Future<Profile> updateProfile({
    required String id,
    required String username,
    required String? displayName,
  }) async {
    if (error != null) throw error!;

    this.username = username;
    this.displayName = displayName;

    return Profile(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: null,
      createdAt: DateTime.utc(2026),
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A container with the profile loaded, as the profile tab would have it.
///
/// The listener stands in for the widget that normally watches the provider:
/// without one the initial load never settles.
Future<ProviderContainer> _loadedContainer(ProfileService service) async {
  final container = ProviderContainer.test(
    overrides: [
      authControllerProvider.overrideWith(_FakeAuthController.new),
      profileServiceProvider.overrideWithValue(service),
    ],
  );

  container.listen(profileControllerProvider, (_, _) {});
  await pumpEventQueue();

  return container;
}

void main() {
  test('trims the edits and stores an empty display name as null', () async {
    final service = _FakeProfileService();
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(username: '  Ada_B  ', displayName: '   ');

    expect(failure, isNull);
    expect(service.username, 'ada_b');
    expect(service.displayName, isNull);

    final summary = container.read(profileControllerProvider).value;
    expect(summary?.profile.username, 'ada_b');
    expect(summary?.profile.displayName, isNull);
  });

  test('rejects an invalid handle before writing', () async {
    final service = _FakeProfileService();
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(username: 'ab', displayName: 'Ada');

    expect(failure, 'At least 3 characters.');
    expect(service.username, isNull);
  });

  test('reports a handle claimed by someone else', () async {
    final service = _FakeProfileService(
      error: const PostgrestException(message: 'duplicate key', code: '23505'),
    );
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(username: 'grace', displayName: 'Ada');

    expect(failure, 'That handle is taken.');
  });
}
