import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/fit.dart';

class FitService {
  FitService(this._client, this._storage);

  final SupabaseClient _client;
  final StorageService _storage;

  static const _table = 'fits';
  static const _columns = 'id, owner_id, image_path, wins, losses, created_at';

  /// Live fits belonging to [ownerId], newest first. Soft-deleted fits are
  /// excluded, which is what the profile grid wants.
  Future<List<Fit>> fetchOwnedBy(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('owner_id', ownerId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return rows.map(Fit.fromJson).toList();
  }

  /// Uploads the photo, then creates the fit row pointing at it.
  ///
  /// If the row insert fails the just-uploaded image is removed, so a failed
  /// attempt does not leave an orphan file in the bucket.
  Future<Fit> createFit({
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final imagePath = await _storage.uploadFitImage(
      ownerId: ownerId,
      bytes: bytes,
      fileExtension: fileExtension,
    );

    try {
      final row = await _client
          .from(_table)
          .insert({'owner_id': ownerId, 'image_path': imagePath})
          .select(_columns)
          .single();

      return Fit.fromJson(row);
    } catch (_) {
      await _storage.removeFitImage(imagePath).catchError((_) {});
      rethrow;
    }
  }

  /// Retires a fit: the row survives so opponents' win counts stay honest,
  /// but the image itself is purged from the bucket.
  ///
  /// `deleted_at` is the only column the owner is granted update on, so this
  /// cannot accidentally touch the fit's record.
  Future<void> softDelete(Fit fit) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', fit.id);

    await _storage.removeFitImage(fit.imagePath).catchError((_) {});
  }

  /// Flags someone else's fit. Reporting the same fit twice is a no-op server
  /// side, so this is safe to call again.
  Future<void> report({
    required String fitId,
    required FitReportReason reason,
    String? note,
  }) async {
    await _client.rpc(
      'report_fit',
      params: {
        'p_fit_id': fitId,
        'p_reason': reason.value,
        if (note != null && note.isNotEmpty) 'p_note': note,
      },
    );
  }
}

final fitServiceProvider = Provider<FitService>((ref) {
  return FitService(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});
