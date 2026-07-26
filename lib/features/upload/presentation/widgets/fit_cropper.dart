import 'package:flutter/cupertino.dart';

import '../../../../core/widgets/app_image_cropper.dart';
import '../../models/upload_state.dart';

/// Frames the staged photo inside the 4:5 window the arena renders.
///
/// The framing itself is [AppImageCropper]; this fixes it to the arena's
/// aspect ratio and wording, and speaks in [PickedFit].
class FitCropper extends StatelessWidget {
  const FitCropper({
    required this.picked,
    required this.onCropChanged,
    this.enabled = true,
    super.key,
  });

  final PickedFit picked;

  /// Reports the framed region in source pixels, on every gesture and once the
  /// window is laid out, so the controller never has to guess a default.
  final ValueChanged<Rect> onCropChanged;

  /// Off while an upload is in flight: the bytes being sent are already cut.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppImageCropper(
      bytes: picked.bytes,
      imageWidth: picked.width,
      imageHeight: picked.height,
      aspectRatio: 4 / 5,
      onCropChanged: onCropChanged,
      enabled: enabled,
      semanticLabel: 'Your fit. Drag or pinch to frame it.',
      caption: 'Drag or pinch to frame. The arena crops fits to 4:5.',
    );
  }
}
