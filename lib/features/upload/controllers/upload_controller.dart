import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/error_messages.dart';
import '../../fits/controllers/my_fits_controller.dart';
import '../models/upload_state.dart';
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

      state = UploadState(picked: picked);
      return null;
    } catch (error) {
      return describeError(error);
    }
  }

  void clear() {
    if (state.isUploading) return;
    state = UploadState.initial;
  }

  /// Uploads the staged photo and adds the fit to the user's grid.
  Future<String?> submit() async {
    final picked = state.picked;
    if (picked == null || state.isUploading) return null;

    state = state.copyWith(isUploading: true);

    try {
      await ref
          .read(myFitsControllerProvider.notifier)
          .addFit(bytes: picked.bytes, fileExtension: picked.fileExtension);

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
