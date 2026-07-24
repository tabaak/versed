import 'dart:typed_data';

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
  const UploadState({this.picked, this.isUploading = false});

  static const UploadState initial = UploadState();

  final PickedFit? picked;
  final bool isUploading;

  bool get hasPick => picked != null;

  /// [picked] is deliberately not nullable-clearable here — use
  /// [UploadState.initial] to drop the staged photo.
  UploadState copyWith({PickedFit? picked, bool? isUploading}) {
    return UploadState(
      picked: picked ?? this.picked,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UploadState &&
            other.picked == picked &&
            other.isUploading == isUploading;
  }

  @override
  int get hashCode => Object.hash(picked, isUploading);

  @override
  String toString() =>
      'UploadState(picked: $picked, isUploading: $isUploading)';
}
