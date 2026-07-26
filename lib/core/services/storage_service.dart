import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Owns the image buckets: the path conventions, uploads and the public URLs
/// the app renders from.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  static const fitsBucket = 'fits';
  static const avatarsBucket = 'avatars';

  static final _random = Random.secure();

  static const _contentTypes = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
  };

  /// The bucket is public, so a fit's URL is a pure function of its stored
  /// path and needs no signing round trip before the arena can render it.
  String fitImageUrl(String path) {
    return _client.storage.from(fitsBucket).getPublicUrl(path);
  }

  /// Uploads a fit photo and returns its storage path.
  ///
  /// Storage RLS only lets a user write inside a folder named after their own
  /// uuid, so [ownerId] must be the signed-in user. The file name itself is
  /// arbitrary — the fit row is created afterwards and points at this path.
  Future<String> uploadFitImage({
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
  }) {
    return _upload(
      bucket: fitsBucket,
      ownerId: ownerId,
      bytes: bytes,
      fileExtension: fileExtension,
    );
  }

  Future<void> removeFitImage(String path) async {
    await _client.storage.from(fitsBucket).remove([path]);
  }

  /// Uploads an avatar and returns its public URL.
  ///
  /// Unlike a fit, the profile row stores the URL rather than the path:
  /// `profiles.avatar_url` also holds Google's avatar for accounts that never
  /// uploaded one, and both kinds are rendered the same way.
  Future<String> uploadAvatarImage({
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = await _upload(
      bucket: avatarsBucket,
      ownerId: ownerId,
      bytes: bytes,
      fileExtension: fileExtension,
    );

    return _client.storage.from(avatarsBucket).getPublicUrl(path);
  }

  /// Deletes the object behind an avatar URL, if that URL is one of ours.
  ///
  /// A no-op for a Google avatar or anything else we did not store, so callers
  /// can hand it whatever the profile row happened to hold.
  Future<void> removeAvatarImage(String? url) async {
    final path = avatarPathFromUrl(url);
    if (path == null) return;

    await _client.storage.from(avatarsBucket).remove([path]);
  }

  /// The storage path inside the avatars bucket for one of our public URLs,
  /// or null when [url] points somewhere else.
  static String? avatarPathFromUrl(String? url) {
    if (url == null) return null;

    const marker = '/object/public/$avatarsBucket/';
    final start = url.indexOf(marker);
    if (start == -1) return null;

    // Supabase appends a cache-busting query on some URLs; the object name
    // ends where it starts.
    final path = url.substring(start + marker.length).split('?').first;
    return path.isEmpty ? null : Uri.decodeComponent(path);
  }

  Future<String> _upload({
    required String bucket,
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final extension = _normalizeExtension(fileExtension);
    final path =
        '$ownerId/${DateTime.now().millisecondsSinceEpoch}'
        '-${_random.nextInt(1 << 32)}.$extension';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypes[extension] ?? 'image/jpeg',
          ),
        );

    return path;
  }

  String _normalizeExtension(String fileExtension) {
    final cleaned = fileExtension.replaceFirst('.', '').toLowerCase();
    return _contentTypes.containsKey(cleaned) ? cleaned : 'jpg';
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});
