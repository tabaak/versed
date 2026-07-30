import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/storage_service.dart';
import '../models/fit.dart';

/// Gets a fit photo out of the app: to the share sheet, or into the camera
/// roll.
///
/// Both routes download the original from storage rather than reusing the
/// image the viewer is showing — that one is decoded down to screen size, and
/// a photo worth keeping should be the full-size file.
class FitExportService {
  FitExportService(this._storage);

  final StorageService _storage;

  /// The album saved fits land in, so they are not scattered through the
  /// camera roll.
  static const albumName = 'VERSED';

  /// Downloads [fit]'s photo and opens the share sheet on it.
  ///
  /// [origin] anchors the popover on iPad, where a share sheet without one is
  /// a hard crash. Callers pass the global rect of the button that was tapped.
  ///
  /// Returns false when the user dismissed the sheet without choosing
  /// anything, so the caller can stay quiet instead of claiming success.
  Future<bool> shareFit(Fit fit, {Rect? origin}) async {
    final bytes = await _storage.downloadFitImage(fit.imagePath);
    final extension = _storage.extensionOf(fit.imagePath);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: _storage.contentTypeOf(fit.imagePath),
          ),
        ],
        // XFile.fromData carries no name of its own; without an override the
        // shared file lands as an unnamed blob in the receiving app.
        fileNameOverrides: ['versed-${fit.id}.$extension'],
        sharePositionOrigin: origin,
      ),
    );

    return result.status != ShareResultStatus.dismissed;
  }

  /// Downloads [fit]'s photo and writes it into the camera roll.
  ///
  /// Returns null once it is saved, or a sentence explaining why it is not.
  /// A refused photo-library prompt is an ordinary outcome rather than an
  /// error, and the reasons the gallery can turn a write down are its own —
  /// they mean nothing to `describeError`, so they are worded here.
  Future<String?> saveToGallery(Fit fit) async {
    try {
      // Writing into a named album needs the broader permission on iOS, not
      // just add-only access. The permission calls are inside the guard
      // because they raise the same way the write does.
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) return 'Allow photo access in Settings to save fits.';
      }

      final bytes = await _storage.downloadFitImage(fit.imagePath);

      // Gal appends the extension itself, so the name goes in without one.
      await Gal.putImageBytes(
        bytes,
        album: albumName,
        name: 'versed-${fit.id}',
      );
      return null;
    } on GalException catch (error) {
      return switch (error.type) {
        GalExceptionType.accessDenied =>
          'Allow photo access in Settings to save fits.',
        GalExceptionType.notEnoughSpace => 'Not enough space on this device.',
        GalExceptionType.notSupportedFormat =>
          "This photo is in a format the gallery won't take.",
        GalExceptionType.unexpected => 'Could not save the photo. Try again.',
      };
    }
  }
}

final fitExportServiceProvider = Provider<FitExportService>((ref) {
  return FitExportService(ref.watch(storageServiceProvider));
});
