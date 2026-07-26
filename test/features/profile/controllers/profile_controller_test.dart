import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:versed/features/auth/controllers/auth_controller.dart';
import 'package:versed/features/auth/models/auth_model.dart';
import 'package:versed/features/profile/controllers/profile_controller.dart';
import 'package:versed/features/profile/models/profile_model.dart';
import 'package:versed/features/profile/services/profile_service.dart';
import 'package:versed/features/upload/models/upload_state.dart';

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
  _FakeProfileService({this.error, this.existingAvatarUrl});

  /// Thrown instead of writing, to exercise the failure paths.
  final Object? error;

  /// What the loaded profile already has as its photo.
  final String? existingAvatarUrl;

  static const uploadedUrl = 'https://cdn.test/avatars/user-1/new.jpg';

  String? username;
  String? displayName;
  String? avatarUrl;
  bool wroteProfile = false;

  Uint8List? uploadedBytes;
  String? uploadedExtension;
  final List<String?> removedAvatars = [];

  @override
  Future<Profile> fetchProfile(String id) async => Profile.empty.copyWith(
    id: id,
    username: 'ada',
    displayName: 'Ada Lovelace',
    avatarUrl: existingAvatarUrl,
  );

  @override
  Future<ProfileStats> fetchStats(String id) async => ProfileStats.empty;

  @override
  Future<String> uploadAvatar({
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    uploadedBytes = bytes;
    uploadedExtension = fileExtension;
    return uploadedUrl;
  }

  @override
  Future<void> removeAvatar(String? url) async => removedAvatars.add(url);

  @override
  Future<Profile> updateProfile({
    required String id,
    required String username,
    required String? displayName,
    required String? avatarUrl,
  }) async {
    if (error != null) throw error!;

    wroteProfile = true;
    this.username = username;
    this.displayName = displayName;
    this.avatarUrl = avatarUrl;

    return Profile(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      createdAt: DateTime.utc(2026),
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A real 1x1 PNG: small enough that the square crop is a no-op, so the
/// controller's upload path runs without decoding anything.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

PickedFit _picked() => PickedFit(
  bytes: _pngBytes,
  fileExtension: 'png',
  width: 1,
  height: 1,
);

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

  test('uploads a new avatar and points the profile at it', () async {
    final service = _FakeProfileService(
      existingAvatarUrl: 'https://cdn.test/avatars/user-1/old.jpg',
    );
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(
          username: 'ada',
          displayName: 'Ada',
          avatar: _picked(),
        );

    expect(failure, isNull);
    expect(service.uploadedBytes, _pngBytes);
    expect(service.avatarUrl, _FakeProfileService.uploadedUrl);
    // The photo it replaced is purged, but only after the row stopped
    // pointing at it.
    expect(service.removedAvatars, ['https://cdn.test/avatars/user-1/old.jpg']);

    final summary = container.read(profileControllerProvider).value;
    expect(summary?.profile.avatarUrl, _FakeProfileService.uploadedUrl);
  });

  test('clears the avatar when the user removes it', () async {
    final service = _FakeProfileService(
      existingAvatarUrl: 'https://cdn.test/avatars/user-1/old.jpg',
    );
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(
          username: 'ada',
          displayName: 'Ada',
          removeAvatar: true,
        );

    expect(failure, isNull);
    expect(service.avatarUrl, isNull);
    expect(service.uploadedBytes, isNull);
    expect(service.removedAvatars, ['https://cdn.test/avatars/user-1/old.jpg']);
  });

  test('keeps the current avatar when the edit does not touch it', () async {
    const existing = 'https://cdn.test/avatars/user-1/old.jpg';
    final service = _FakeProfileService(existingAvatarUrl: existing);
    final container = await _loadedContainer(service);

    await container
        .read(profileControllerProvider.notifier)
        .updateProfile(username: 'ada_b', displayName: 'Ada');

    expect(service.avatarUrl, existing);
    expect(service.removedAvatars, isEmpty);
  });

  test('discards an uploaded avatar when the save is rejected', () async {
    final service = _FakeProfileService(
      error: const PostgrestException(message: 'duplicate key', code: '23505'),
    );
    final container = await _loadedContainer(service);

    final failure = await container
        .read(profileControllerProvider.notifier)
        .updateProfile(
          username: 'grace',
          displayName: 'Ada',
          avatar: _picked(),
        );

    expect(failure, 'That handle is taken.');
    expect(service.wroteProfile, isFalse);
    // No orphan file left in the bucket for a save that never landed.
    expect(service.removedAvatars, [_FakeProfileService.uploadedUrl]);
  });
}
