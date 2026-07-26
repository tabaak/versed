import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/upload_state.dart';

/// Frames the staged photo inside the 4:5 window the arena renders, and lets
/// the user drag and pinch to choose what survives the crop.
///
/// The photo always covers the window — there is no letterboxing and no
/// zooming back out past the fill — so a fit can never enter the arena with
/// empty bars down its sides.
class FitCropper extends StatefulWidget {
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
  State<FitCropper> createState() => _FitCropperState();
}

class _FitCropperState extends State<FitCropper> {
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

  /// The laid-out 4:5 window. Zero until the first layout pass.
  Size _window = Size.zero;

  /// Until the user drags, the frame follows the window instead of holding
  /// its position — so a rotation or keyboard resize re-centers rather than
  /// stranding the photo against an edge.
  bool _framedByUser = false;

  @override
  void didUpdateWidget(FitCropper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different photo is a different frame — start it centered again.
    if (widget.picked != oldWidget.picked) {
      _scale = 1;
      _framedByUser = false;
      _offset = _centeredOffset(_window, 1);
      _reportCropAfterFrame();
    }
  }

  /// Scale at which the photo exactly covers the window.
  double _coverScale(Size window) {
    if (window.isEmpty) return 0;
    final byWidth = window.width / widget.picked.width;
    final byHeight = window.height / widget.picked.height;
    return byWidth > byHeight ? byWidth : byHeight;
  }

  Size _drawnSize(Size window, double scale) {
    final cover = _coverScale(window) * scale;
    return Size(widget.picked.width * cover, widget.picked.height * cover);
  }

  /// Where the photo sits when nothing has been framed yet: the middle of it
  /// showing, matching the arena's own centered crop.
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
  /// for the frame to end, since it notifies a controller.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 4 / 5,
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

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: widget.enabled ? _onScaleStart : null,
                      onScaleUpdate: widget.enabled ? _onScaleUpdate : null,
                      onScaleEnd: widget.enabled ? _onScaleEnd : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: _offset.dx,
                            top: _offset.dy,
                            width: drawn.width,
                            height: drawn.height,
                            child: Image.memory(
                              widget.picked.bytes,
                              // The box is already the photo's aspect ratio,
                              // so filling it neither crops nor stretches.
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                              semanticLabel:
                                  'Your fit. Drag or pinch to frame it.',
                            ),
                          ),
                          const Positioned.fill(
                            child: IgnorePointer(child: _CropGuides()),
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
        const SizedBox(height: 12),
        const Text(
          'Drag or pinch to frame. The arena crops fits to 4:5.',
          style: AppTextStyles.meta,
        ),
      ],
    );
  }
}

/// Thirds grid over the frame — the cue that the photo can be moved. Hairline
/// and dim, so it never competes with the fit itself.
class _CropGuides extends StatelessWidget {
  const _CropGuides();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CropGuidesPainter());
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
