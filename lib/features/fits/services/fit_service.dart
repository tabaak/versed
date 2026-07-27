import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/fit.dart';
import '../models/fit_genre.dart';

class FitService {
  FitService(this._client, this._storage);

  final SupabaseClient _client;
  final StorageService _storage;

  static const _table = 'fits';
  static const _savedTable = 'saved_fits';
  static const _columns =
      'id, owner_id, image_path, genre, wins, losses, created_at';

  /// The saved grid asks for two things the profile grid never needs: whose
  /// fit it is, and whether the fit has since left the arena.
  ///
  /// The owner embed is pinned to the `owner_id` foreign key by name: because
  /// saved_fits joins fits to profiles as well, there are two ways to get from
  /// a fit to a profile and an unqualified `profiles(...)` is rejected as
  /// ambiguous.
  static const _savedColumns =
      'fit:fits('
      'id, owner_id, image_path, genre, wins, losses, created_at, '
      'deleted_at, hidden_at, '
      'owner:profiles!fits_owner_id_fkey(username, display_name)'
      ')';

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

  /// The fits [userId] has saved, most recently saved first.
  ///
  /// Retired and hidden fits stay in the list: the grid shows them as a
  /// placeholder tile rather than dropping them without explanation.
  Future<List<Fit>> fetchSavedBy(String userId) async {
    final rows = await _client
        .from(_savedTable)
        .select(_savedColumns)
        .eq('user_id', userId)
        // Orders on saved_fits.created_at — when it was saved, not when the
        // fit was uploaded.
        .order('created_at', ascending: false);

    return rows
        .map((row) => row['fit'])
        .whereType<Map<String, dynamic>>()
        .map(_savedFitFromJson)
        .toList();
  }

  /// Flattens the embedded owner onto the fit row, which is the shape
  /// [Fit.fromJson] reads.
  static Fit _savedFitFromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;

    return Fit.fromJson({
      ...json,
      'username': owner?['username'],
      'display_name': owner?['display_name'],
    });
  }

  /// Saves a fit for [userId]. Saving one that is already saved is a no-op,
  /// so a double tap cannot fail.
  Future<void> saveFit({required String userId, required String fitId}) async {
    await _client
        .from(_savedTable)
        .upsert(
          {'user_id': userId, 'fit_id': fitId},
          onConflict: 'user_id, fit_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> unsaveFit({
    required String userId,
    required String fitId,
  }) async {
    await _client
        .from(_savedTable)
        .delete()
        .eq('user_id', userId)
        .eq('fit_id', fitId);
  }

  /// Uploads the photo, then creates the fit row pointing at it.
  ///
  /// If the row insert fails the just-uploaded image is removed, so a failed
  /// attempt does not leave an orphan file in the bucket.
  Future<Fit> createFit({
    required String ownerId,
    required Uint8List bytes,
    required String fileExtension,
    required FitGenre genre,
  }) async {
    final imagePath = await _storage.uploadFitImage(
      ownerId: ownerId,
      bytes: bytes,
      fileExtension: fileExtension,
    );

    try {
      final row = await _client
          .from(_table)
          .insert({
            'owner_id': ownerId,
            'image_path': imagePath,
            'genre': genre.value,
          })
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
