import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Owns the `fits` storage bucket: the path convention, uploads and the public
/// URLs the arena renders from.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  static const fitsBucket = 'fits';

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
  }) async {
    final extension = _normalizeExtension(fileExtension);
    final path =
        '$ownerId/${DateTime.now().millisecondsSinceEpoch}'
        '-${_random.nextInt(1 << 32)}.$extension';

    await _client.storage
        .from(fitsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypes[extension] ?? 'image/jpeg',
          ),
        );

    return path;
  }

  Future<void> removeFitImage(String path) async {
    await _client.storage.from(fitsBucket).remove([path]);
  }

  String _normalizeExtension(String fileExtension) {
    final cleaned = fileExtension.replaceFirst('.', '').toLowerCase();
    return _contentTypes.containsKey(cleaned) ? cleaned : 'jpg';
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});
