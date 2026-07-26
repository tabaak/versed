import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Frames a photo inside a window of a given aspect ratio, and lets the user
/// drag and pinch to choose what survives the crop.
///
/// The photo always covers the window — there is no letterboxing and no
/// zooming back out past the fill — so a crop can never come out with empty
/// bars down its sides.
class AppImageCropper extends StatefulWidget {
  const AppImageCropper({
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.aspectRatio,
    required this.onCropChanged,
    this.semanticLabel = 'Photo. Drag or pinch to frame it.',
    this.caption,
    this.circular = false,
    this.enabled = true,
    super.key,
  });

  final Uint8List bytes;

  /// Pixel size of [bytes], needed to map what the user framed on screen back
  /// onto the source photo.
  final int imageWidth;
  final int imageHeight;

  /// Width over height of the crop window — 4/5 for a fit, 1 for an avatar.
  final double aspectRatio;

  /// Reports the framed region in source pixels, on every gesture and once the
  /// window is laid out, so the caller never has to guess a default.
  final ValueChanged<Rect> onCropChanged;

  final String semanticLabel;

  /// Optional line under the frame explaining what the crop is for.
  final String? caption;

  /// Dims everything outside the inscribed circle, for photos that will be
  /// displayed round. The crop itself stays rectangular — only the preview is
  /// masked.
  final bool circular;

  /// Off while an upload is in flight: the bytes being sent are already cut.
  final bool enabled;

  @override
  State<AppImageCropper> createState() => _AppImageCropperState();
}

class _AppImageCropperState extends State<AppImageCropper> {
  /// How far past the cover fill the user may zoom. Past this, a 1440pt-wide
  /// source starts showing its own pixels.
  static const _maxScale = 4.0;

  /// Zoom relative to the cover fill, where 1 exactly fills the window.
  double _scale = 1;

  /// Top-left of the drawn photo relative to the window's top-left. Never
  /// positive, since the photo overhangs every side it can.
  Offset _offset = Offset.zero;

  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  /// The laid-out window. Zero until the first layout pass.
  Size _window = Size.zero;

  /// Until the user drags, the frame follows the window instead of holding
  /// its position — so a rotation or keyboard resize re-centers rather than
  /// stranding the photo against an edge.
  bool _framedByUser = false;

  @override
  void didUpdateWidget(AppImageCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different photo, or a different window shape, is a different frame —
    // start it centered again.
    if (!identical(widget.bytes, oldWidget.bytes) ||
        widget.aspectRatio != oldWidget.aspectRatio) {
      _scale = 1;
      _framedByUser = false;
      _offset = _centeredOffset(_window, 1);
      _reportCropAfterFrame();
    }
  }

  /// Scale at which the photo exactly covers the window.
  double _coverScale(Size window) {
    if (window.isEmpty) return 0;
    final byWidth = window.width / widget.imageWidth;
    final byHeight = window.height / widget.imageHeight;
    return byWidth > byHeight ? byWidth : byHeight;
  }

  Size _drawnSize(Size window, double scale) {
    final cover = _coverScale(window) * scale;
    return Size(widget.imageWidth * cover, widget.imageHeight * cover);
  }

  /// Where the photo sits when nothing has been framed yet: the middle of it
  /// showing, matching the centered crop callers default to.
  Offset _centeredOffset(Size window, double scale) {
    final drawn = _drawnSize(window, scale);
    return Offset(
      (window.width - drawn.width) / 2,
      (window.height - drawn.height) / 2,
    );
  }

  /// Keeps every edge of the window covered by photo.
  Offset _clampOffset(Offset offset, Size window, double scale) {
    final drawn = _drawnSize(window, scale);
    return Offset(
      offset.dx.clamp(window.width - drawn.width, 0.0),
      offset.dy.clamp(window.height - drawn.height, 0.0),
    );
  }

  /// Picks up the window size during layout. Reporting the crop has to wait
  /// for the frame to end, since it notifies a caller.
  void _onWindowLaidOut(Size window) {
    if (window == _window) return;
    _window = window;
    _offset = _framedByUser
        ? _clampOffset(_offset, window, _scale)
        : _centeredOffset(window, _scale);
    _reportCropAfterFrame();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartOffset = _offset;
    _gestureStartFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = (_gestureStartScale * details.scale).clamp(1.0, _maxScale);
    final growth = scale / _gestureStartScale;

    // Pin the photo point under the fingers in place while zooming, then apply
    // however far the fingers also travelled.
    final zoomed =
        _gestureStartFocalPoint -
        (_gestureStartFocalPoint - _gestureStartOffset) * growth;
    final panned = zoomed + (details.localFocalPoint - _gestureStartFocalPoint);

    setState(() {
      _scale = scale;
      _offset = _clampOffset(panned, _window, scale);
      _framedByUser = true;
    });
    _reportCrop();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    HapticFeedback.selectionClick();
  }

  void _reportCropAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportCrop();
    });
  }

  void _reportCrop() {
    if (_window.isEmpty) return;

    final cover = _coverScale(_window) * _scale;
    widget.onCropChanged(
      Rect.fromLTWH(
        -_offset.dx / cover,
        -_offset.dy / cover,
        _window.width / cover,
        _window.height / cover,
      ),
    );
  }

  Map<Type, GestureRecognizerFactory> get _gestures => {
    _EagerScaleGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<_EagerScaleGestureRecognizer>(
          () => _EagerScaleGestureRecognizer(debugOwner: this),
          (recognizer) => recognizer
            ..onStart = _onScaleStart
            ..onUpdate = _onScaleUpdate
            ..onEnd = _onScaleEnd,
        ),
  };

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final window = constraints.biggest;
                    _onWindowLaidOut(window);
                    final drawn = _drawnSize(window, _scale);

                    return RawGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      gestures: widget.enabled
                          ? _gestures
                          : const <Type, GestureRecognizerFactory>{},
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: _offset.dx,
                            top: _offset.dy,
                            width: drawn.width,
                            height: drawn.height,
                            child: Image.memory(
                              widget.bytes,
                              // The box is already the photo's aspect ratio,
                              // so filling it neither crops nor stretches.
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                              semanticLabel: widget.semanticLabel,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _CropGuides(circular: widget.circular),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 12),
          Text(caption, textAlign: TextAlign.center, style: AppTextStyles.meta),
        ],
      ],
    );
  }
}

/// Wins the gesture arena on contact, so framing works with the cropper
/// inside a scrolling page: a drag across the photo moves the frame instead of
/// panning the list underneath.
///
/// Claiming the pointer as it goes down is what defeats the scrollable —
/// accepting only once the drag has travelled far enough would come after the
/// list has already taken it.
class _EagerScaleGestureRecognizer extends ScaleGestureRecognizer {
  _EagerScaleGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// The cue that the photo can be moved: a thirds grid over a rectangular
/// frame, or the circle a round photo will be cut to. Hairline and dim, so it
/// never competes with the photo itself.
class _CropGuides extends StatelessWidget {
  const _CropGuides({required this.circular});

  final bool circular;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: circular ? _CircleGuidePainter() : _CropGuidesPainter(),
    );
  }
}

class _CropGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CropGuidesPainter oldDelegate) => false;
}

/// Scrims the corners the round display will hide, so what the user frames
/// inside the circle is what they will see.
class _CircleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2;

    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas
      ..drawPath(
        scrim,
        Paint()..color = AppColors.canvas.withValues(alpha: 0.6),
      )
      ..drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = AppColors.textPrimary.withValues(alpha: 0.3),
      );
  }

  @override
  bool shouldRepaint(_CircleGuidePainter oldDelegate) => false;
}
