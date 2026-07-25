import 'dart:typed_data';

import '../../fits/models/fit_genre.dart';

/// A photo chosen on device but not yet in the arena.
class PickedFit {
  const PickedFit({required this.bytes, required this.fileExtension});

  final Uint8List bytes;

  /// Extension without the dot, used to pick the upload's content type.
  final String fileExtension;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PickedFit &&
            other.fileExtension == fileExtension &&
            // Byte lists are large; identity is enough to tell two picks
            // apart because every pick allocates a fresh list.
            identical(other.bytes, bytes);
  }

  @override
  int get hashCode => Object.hash(identityHashCode(bytes), fileExtension);

  @override
  String toString() =>
      'PickedFit(bytes: ${bytes.length} bytes, '
      'fileExtension: $fileExtension)';
}

/// State of the upload tab: nothing picked, a photo staged, or an upload in
/// flight.
class UploadState {
  const UploadState({this.picked, this.genre, this.isUploading = false});

  static const UploadState initial = UploadState();

  final PickedFit? picked;

  /// Which genre the fit will battle in. Null until the user picks one, and
  /// there is no default: the genre decides who the fit is ever compared
  /// against, so guessing it on the user's behalf is worse than asking.
  final FitGenre? genre;
  final bool isUploading;

  bool get hasPick => picked != null;

  /// The arena needs both a photo and a genre before it will take the fit.
  bool get canSubmit => picked != null && genre != null && !isUploading;

  /// [picked] and [genre] are deliberately not nullable-clearable here — use
  /// [UploadState.initial] to drop the staged photo.
  UploadState copyWith({
    PickedFit? picked,
    FitGenre? genre,
    bool? isUploading,
  }) {
    return UploadState(
      picked: picked ?? this.picked,
      genre: genre ?? this.genre,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UploadState &&
            other.picked == picked &&
            other.genre == genre &&
            other.isUploading == isUploading;
  }

  @override
  int get hashCode => Object.hash(picked, genre, isUploading);

  @override
  String toString() =>
      'UploadState(picked: $picked, genre: ${genre?.value}, '
      'isUploading: $isUploading)';
}
