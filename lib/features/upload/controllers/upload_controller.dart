import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/error_messages.dart';
import '../../fits/controllers/my_fits_controller.dart';
import '../../fits/models/fit_genre.dart';
import '../models/upload_state.dart';
import '../services/image_crop_service.dart';
import '../services/image_pick_service.dart';

/// Drives the upload tab: stage a photo, then send it to the arena.
///
/// Both actions return null on success or a message worth showing, so the page
/// stays free of error mapping.
class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => UploadState.initial;

  Future<String?> pick(ImageSource source) async {
    try {
      final picked = await ref.read(imagePickServiceProvider).pick(source);
      // A null pick means the user backed out — not a failure.
      if (picked == null) return null;

      // A fresh photo is a fresh fit, so the previous genre choice goes with
      // the previous photo.
      state = UploadState(picked: picked);
      return null;
    } catch (error) {
      return describeError(error);
    }
  }

  /// Records the 4:5 region the cropper is showing, in source pixels. Cheap
  /// enough to call on every gesture frame: nothing is re-encoded until
  /// [submit].
  void setCrop(Rect crop) {
    if (state.picked == null || state.isUploading || state.crop == crop) return;
    state = state.copyWith(crop: crop);
  }

  void selectGenre(FitGenre genre) {
    if (state.isUploading) return;
    state = state.copyWith(genre: genre);
  }

  void clear() {
    if (state.isUploading) return;
    state = UploadState.initial;
  }

  /// Crops the staged photo to what the user framed, then uploads it and adds
  /// the fit to the user's grid.
  Future<String?> submit() async {
    final picked = state.picked;
    final genre = state.genre;
    final crop = state.cropOrCentered;
    if (picked == null || genre == null || crop == null || state.isUploading) {
      return null;
    }

    state = state.copyWith(isUploading: true);

    try {
      final cropped = await ref
          .read(imageCropServiceProvider)
          .crop(source: picked, crop: crop);

      await ref
          .read(myFitsControllerProvider.notifier)
          .addFit(
            bytes: cropped.bytes,
            fileExtension: cropped.fileExtension,
            genre: genre,
          );

      state = UploadState.initial;
      return null;
    } catch (error) {
      state = state.copyWith(isUploading: false);
      return describeError(error);
    }
  }
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
