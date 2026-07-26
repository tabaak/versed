import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/upload_state.dart';

/// Wraps the platform photo picker.
///
/// Photos are downscaled and recompressed on device: the arena renders fits at
/// 4:5, so anything past ~1440pt wide is bytes nobody sees.
class ImagePickService {
  ImagePickService(this._picker);

  final ImagePicker _picker;

  static const _maxWidth = 1440.0;
  static const _maxHeight = 1800.0;
  static const _quality = 85;

  /// Returns null when the user backs out of the picker.
  Future<PickedFit?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxWidth,
      maxHeight: _maxHeight,
      imageQuality: _quality,
      requestFullMetadata: false,
    );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final size = await _sizeOf(bytes);

    return PickedFit(
      bytes: bytes,
      fileExtension: _extensionOf(file.name),
      width: size.width,
      height: size.height,
    );
  }

  /// Reads the dimensions the cropper frames against straight from the image
  /// header, without decoding a single pixel.
  Future<({int width, int height})> _sizeOf(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return (width: descriptor.width, height: descriptor.height);
    } finally {
      descriptor.dispose();
    }
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

final imagePickServiceProvider = Provider<ImagePickService>((ref) {
  return ImagePickService(ImagePicker());
});
