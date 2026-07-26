import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/upload_state.dart';

/// Cuts a staged photo down to the 4:5 region the user framed.
///
/// The arena only ever renders 4:5, so the crop is baked into the bytes before
/// upload rather than stored alongside them — every screen that shows a fit
/// then gets the same framing for free.
class ImageCropService {
  const ImageCropService();

  /// [crop] is in source pixels and is expected to be 4:5; it is clamped to
  /// the photo's bounds, so a frame nudged past an edge still yields an image.
  ///
  /// Returns [source] untouched when the crop already covers the whole photo.
  Future<PickedFit> crop({
    required PickedFit source,
    required Rect crop,
  }) async {
    final rect = _clamp(crop, source.width, source.height);
    if (rect.width == source.width && rect.height == source.height) {
      return source;
    }

    // Decoding and re-encoding a multi-megapixel photo takes long enough to
    // drop frames, so it runs off the UI isolate.
    final bytes = await compute(
      _cropToJpeg,
      _CropRequest(
        bytes: source.bytes,
        x: rect.left.round(),
        y: rect.top.round(),
        width: rect.width.round(),
        height: rect.height.round(),
      ),
    );

    return PickedFit(
      bytes: bytes,
      // Always JPEG once re-encoded, whatever came out of the picker.
      fileExtension: 'jpg',
      width: rect.width.round(),
      height: rect.height.round(),
    );
  }

  Rect _clamp(Rect crop, int width, int height) {
    final w = crop.width.clamp(1.0, width.toDouble());
    final h = crop.height.clamp(1.0, height.toDouble());
    return Rect.fromLTWH(
      crop.left.clamp(0.0, width - w),
      crop.top.clamp(0.0, height - h),
      w,
      h,
    );
  }
}

/// Quality is matched to the picker's own recompression, so cropping does not
/// visibly cost a second generation of artifacts.
const _jpegQuality = 85;

class _CropRequest {
  const _CropRequest({
    required this.bytes,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int x;
  final int y;
  final int width;
  final int height;
}

/// Top-level so it can run in the isolate [compute] spawns.
Uint8List _cropToJpeg(_CropRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    throw const FormatException('That photo could not be read.');
  }

  // Flutter renders EXIF-rotated photos upright, so the crop the user framed
  // is in upright coordinates — bake the rotation in before cutting.
  final upright = img.bakeOrientation(decoded);

  final cropped = img.copyCrop(
    upright,
    x: request.x,
    y: request.y,
    width: request.width,
    height: request.height,
  );

  return img.encodeJpg(cropped, quality: _jpegQuality);
}

final imageCropServiceProvider = Provider<ImageCropService>((ref) {
  return const ImageCropService();
});
