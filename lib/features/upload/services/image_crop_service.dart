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

  /// [crop] is in source pixels and is clamped to the photo's bounds, so a
  /// frame nudged past an edge still yields an image.
  ///
  /// [maxDimension] caps the longest side of the result, for callers that
  /// render far smaller than the picker delivers — an avatar, say.
  ///
  /// Returns [source] untouched when there is nothing to cut or shrink.
  Future<PickedFit> crop({
    required PickedFit source,
    required Rect crop,
    int? maxDimension,
  }) async {
    final rect = _clamp(crop, source.width, source.height);
    final width = rect.width.round();
    final height = rect.height.round();

    final coversAll = width == source.width && height == source.height;
    final scale = _scaleFor(width, height, maxDimension);
    if (coversAll && scale == 1) return source;

    // Decoding and re-encoding a multi-megapixel photo takes long enough to
    // drop frames, so it runs off the UI isolate.
    final bytes = await compute(
      _cropToJpeg,
      _CropRequest(
        bytes: source.bytes,
        x: rect.left.round(),
        y: rect.top.round(),
        width: width,
        height: height,
        maxDimension: maxDimension,
      ),
    );

    return PickedFit(
      bytes: bytes,
      // Always JPEG once re-encoded, whatever came out of the picker.
      fileExtension: 'jpg',
      width: (width * scale).round(),
      height: (height * scale).round(),
    );
  }

  /// How far the crop has to shrink to respect [maxDimension]; 1 when it
  /// already fits.
  static double _scaleFor(int width, int height, int? maxDimension) {
    if (maxDimension == null) return 1;

    final longest = width > height ? width : height;
    return longest <= maxDimension ? 1 : maxDimension / longest;
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
    this.maxDimension,
  });

  final Uint8List bytes;
  final int x;
  final int y;
  final int width;
  final int height;
  final int? maxDimension;
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

  var cropped = img.copyCrop(
    upright,
    x: request.x,
    y: request.y,
    width: request.width,
    height: request.height,
  );

  final max = request.maxDimension;
  if (max != null && (cropped.width > max || cropped.height > max)) {
    cropped = img.copyResize(
      cropped,
      width: cropped.width >= cropped.height ? max : null,
      height: cropped.height > cropped.width ? max : null,
      interpolation: img.Interpolation.average,
    );
  }

  return img.encodeJpg(cropped, quality: _jpegQuality);
}

final imageCropServiceProvider = Provider<ImageCropService>((ref) {
  return const ImageCropService();
});
