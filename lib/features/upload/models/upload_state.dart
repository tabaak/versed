import 'dart:typed_data';
import 'dart:ui';

import '../../fits/models/fit_genre.dart';

/// A photo chosen on device but not yet in the arena.
class PickedFit {
  const PickedFit({
    required this.bytes,
    required this.fileExtension,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;

  /// Extension without the dot, used to pick the upload's content type.
  final String fileExtension;

  /// Pixel size of [bytes]. The cropper needs it to map what the user framed
  /// on screen back onto the source photo.
  final int width;
  final int height;

  /// The largest 4:5 rect that fits the photo, centered — where the frame
  /// starts before the user drags it anywhere.
  Rect get centeredCrop {
    final targetWidth = width * 5 <= height * 4
        ? width.toDouble()
        : height * 4 / 5;
    final targetHeight = targetWidth * 5 / 4;
    return Rect.fromLTWH(
      (width - targetWidth) / 2,
      (height - targetHeight) / 2,
      targetWidth,
      targetHeight,
    );
  }

  /// The largest square that fits the photo, centered — the framing an avatar
  /// gets, since nothing lets the user drag it yet.
  Rect get centeredSquareCrop {
    final side = (width < height ? width : height).toDouble();
    return Rect.fromLTWH((width - side) / 2, (height - side) / 2, side, side);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PickedFit &&
            other.fileExtension == fileExtension &&
            other.width == width &&
            other.height == height &&
            // Byte lists are large; identity is enough to tell two picks
            // apart because every pick allocates a fresh list.
            identical(other.bytes, bytes);
  }

  @override
  int get hashCode =>
      Object.hash(identityHashCode(bytes), fileExtension, width, height);

  @override
  String toString() =>
      'PickedFit(bytes: ${bytes.length} bytes, '
      'fileExtension: $fileExtension, size: ${width}x$height)';
}

/// State of the upload tab: nothing picked, a photo staged, or an upload in
/// flight.
class UploadState {
  const UploadState({
    this.picked,
    this.genre,
    this.crop,
    this.isUploading = false,
  });

  static const UploadState initial = UploadState();

  final PickedFit? picked;

  /// The 4:5 region of [picked], in source pixels, that the user framed. Null
  /// until the cropper reports a frame; [cropOrCentered] fills in the default.
  final Rect? crop;

  /// Which genre the fit will battle in. Null until the user picks one, and
  /// there is no default: the genre decides who the fit is ever compared
  /// against, so guessing it on the user's behalf is worse than asking.
  final FitGenre? genre;
  final bool isUploading;

  bool get hasPick => picked != null;

  /// What the arena will actually receive: the framed crop, or a centered one
  /// if the user never touched the frame.
  Rect? get cropOrCentered => crop ?? picked?.centeredCrop;

  /// The arena needs both a photo and a genre before it will take the fit.
  bool get canSubmit => picked != null && genre != null && !isUploading;

  /// [picked] and [genre] are deliberately not nullable-clearable here — use
  /// [UploadState.initial] to drop the staged photo.
  UploadState copyWith({
    PickedFit? picked,
    FitGenre? genre,
    Rect? crop,
    bool? isUploading,
  }) {
    return UploadState(
      picked: picked ?? this.picked,
      genre: genre ?? this.genre,
      crop: crop ?? this.crop,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UploadState &&
            other.picked == picked &&
            other.genre == genre &&
            other.crop == crop &&
            other.isUploading == isUploading;
  }

  @override
  int get hashCode => Object.hash(picked, genre, crop, isUploading);

  @override
  String toString() =>
      'UploadState(picked: $picked, genre: ${genre?.value}, '
      'crop: $crop, isUploading: $isUploading)';
}
