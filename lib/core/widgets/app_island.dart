import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// What a message means, which decides its icon and accent.
enum AppIslandStatus { neutral, success, error }

/// Confirmations, presented as an island that opens at the top of the screen.
///
/// On an iPhone with a Dynamic Island the pill starts life at the exact
/// footprint of the hardware cutout, so the notification reads as the cutout
/// itself stretching open. Everywhere else — Android, older iPhones, the
/// simulator — the same pill floats just under the status bar, which is why
/// none of this depends on the hardware actually being there.
///
/// Only one island is on screen at a time: a second message replaces the
/// first rather than stacking on top of it.
abstract final class AppIsland {
  /// The pill's own box. Its size is what the spring drives, so this is the
  /// handle a test measures the animation by.
  static const shapeKey = ValueKey('app-island-shape');

  static OverlayEntry? _current;

  /// How long a message stays open before it collapses on its own.
  static const _visibleDuration = Duration(seconds: 3);

  static void show({
    required BuildContext context,
    required String message,
    AppIslandStatus status = AppIslandStatus.neutral,
    Duration duration = _visibleDuration,
  }) {
    // The root overlay, so an island outlives the page that raised it — a
    // confirmation for something that closes a page has to survive the pop.
    final overlay = Overlay.of(context, rootOverlay: true);

    _current?.remove();
    _current = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _AppIslandOverlay(
        message: message,
        status: status,
        duration: duration,
        onDismissed: () {
          if (!entry.mounted) return;
          entry.remove();
          if (identical(_current, entry)) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  static void success({
    required BuildContext context,
    required String message,
  }) {
    show(context: context, message: message, status: AppIslandStatus.success);
  }

  static void error({required BuildContext context, required String message}) {
    show(context: context, message: message, status: AppIslandStatus.error);
  }
}

/// The animated pill itself.
///
/// Split from [AppIsland] so the overlay entry owns a real element with a
/// ticker — the animation has to keep running while the page underneath does
/// whatever it was doing.
class _AppIslandOverlay extends StatefulWidget {
  const _AppIslandOverlay({
    required this.message,
    required this.status,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AppIslandStatus status;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppIslandOverlay> createState() => _AppIslandOverlayState();
}

class _AppIslandOverlayState extends State<_AppIslandOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  /// Opening spring. Damping 0.75 is the app's motion signature — enough
  /// overshoot to feel physical, not enough to wobble.
  static final _openSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 340,
    ratio: 0.75,
  );

  static const _closeDuration = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController.unbounded(
      vsync: this,
      // A resting value is still needed for the reduced-motion path, where the
      // controller is set rather than simulated.
      duration: _closeDuration,
    );

    // Scheduled rather than run inline: the first frame needs the island
    // closed, or there is nothing for the spring to open from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _open();
    });
  }

  void _open() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      // A little starting velocity, so the pill is already moving on the frame
      // it appears instead of easing off a dead stop.
      _controller.animateWith(SpringSimulation(_openSpring, 0, 1, 6));
    }

    // The island carries confirmations the user did not ask to see, so it
    // announces itself with the lightest tick there is.
    HapticFeedback.selectionClick();

    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();

    if (!MediaQuery.disableAnimationsOf(context)) {
      await _controller.animateTo(
        0,
        duration: _closeDuration,
        curve: Curves.easeInCubic,
      );
    }

    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _IslandGeometry.of(context, message: widget.message);

    return Positioned(
      top: geometry.top,
      left: 0,
      right: 0,
      child: Semantics(
        liveRegion: true,
        label: widget.message,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            // Flicking it back up towards the notch is the gesture the shape
            // invites, so it dismisses too.
            onVerticalDragEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy < -200) _close();
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _IslandShape(
                progress: _controller.value,
                geometry: geometry,
                message: widget.message,
                status: widget.status,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the pill at a given point in its open/close travel.
class _IslandShape extends StatelessWidget {
  const _IslandShape({
    required this.progress,
    required this.geometry,
    required this.message,
    required this.status,
  });

  /// Where the corner radius stops tracking half the height, so a tall open
  /// island reads as a rounded rectangle rather than an oval.
  static const _maxRadius = 26.0;

  /// 0 is closed, 1 is open. Overshoots past 1 while the spring settles.
  final double progress;
  final _IslandGeometry geometry;
  final String message;
  final AppIslandStatus status;

  Color get _statusColor => switch (status) {
    AppIslandStatus.neutral => AppColors.textPrimary,
    AppIslandStatus.success => AppColors.success,
    AppIslandStatus.error => AppColors.error,
  };

  IconData get _statusIcon => switch (status) {
    AppIslandStatus.neutral => CupertinoIcons.info_circle_fill,
    AppIslandStatus.success => CupertinoIcons.check_mark_circled_solid,
    AppIslandStatus.error => CupertinoIcons.exclamationmark_circle_fill,
  };

  /// Where a value that starts at [begin] and finishes at [end] sits, given
  /// the shape's overall travel. Staggering the parts this way is what makes
  /// the island read as opening rather than as a box being resized.
  double _stage(double begin, double end) {
    return ((progress - begin) / (end - begin)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Width is clamped because the spring overshoots deliberately, and an
    // island already at full width has nowhere left to go.
    final width = math.min(
      geometry.expandedSize.width,
      lerpDouble(
        geometry.collapsedSize.width,
        geometry.expandedSize.width,
        progress,
      )!,
    );
    final height = lerpDouble(
      geometry.collapsedSize.height,
      geometry.expandedSize.height,
      progress.clamp(0.0, 1.0),
    )!;

    // Content arrives once the shape has committed to opening, and leaves
    // first on the way out.
    final contentOpacity = _stage(0.32, 0.72);
    final iconScale = lerpDouble(
      0.4,
      1,
      Curves.easeOutBack.transform(_stage(0.4, 0.9)),
    )!;

    // A capsule while it is short, easing off once it grows tall enough that
    // a true capsule would bow out into an oval. The cutout it stands in for
    // is a capsule; the opened island is a rounded rectangle, same as the
    // real one.
    final radius = math.min(height / 2, _maxRadius);

    return SizedBox(
      key: AppIsland.shapeKey,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.island,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.island.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          // The content is laid out at its final size the whole way through
          // and revealed by the shape growing over it. Letting it lay itself
          // out at the live width instead would reflow the text on every
          // frame of the spring.
          child: OverflowBox(
            maxWidth: geometry.expandedSize.width,
            maxHeight: geometry.expandedSize.height,
            child: SizedBox(
              width: geometry.expandedSize.width,
              height: geometry.expandedSize.height,
              child: Opacity(
                opacity: contentOpacity,
                child: Padding(
                  // The top inset is what keeps the message clear of the
                  // sensor hardware; without it the text renders behind an
                  // opaque cutout and is simply never seen.
                  padding: EdgeInsets.only(
                    left: _IslandGeometry.horizontalPadding,
                    right: _IslandGeometry.horizontalPadding,
                    top: geometry.contentInset,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: iconScale,
                        child: Icon(
                          _statusIcon,
                          size: _IslandGeometry.iconSize,
                          color: _statusColor,
                        ),
                      ),
                      const SizedBox(width: _IslandGeometry.iconGap),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: _IslandGeometry.maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: _IslandGeometry.textStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the island sits and how big it is at each end of its travel.
///
/// The open size is measured up front rather than discovered by layout: the
/// shape animates between two known sizes, so both have to be numbers before
/// the first frame.
class _IslandGeometry {
  const _IslandGeometry({
    required this.collapsedSize,
    required this.expandedSize,
    required this.top,
    required this.contentInset,
  });

  static const horizontalPadding = 16.0;
  static const verticalPadding = 12.0;
  static const iconSize = 18.0;
  static const iconGap = 10.0;
  static const maxLines = 2;

  static const textStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// The Dynamic Island's own footprint, in logical pixels.
  static const _hardwareSize = Size(126, 37.33);
  static const _hardwareTop = 11.0;

  /// The top inset every Dynamic Island iPhone reports. Notched and
  /// flat-top phones all report less, so this separates them without a
  /// device lookup table.
  static const _hardwareTopInset = 59.0;

  /// Fallback footprint where there is no cutout to imitate — narrower than
  /// the real island, so it reads as a deliberate pill rather than a guess at
  /// hardware that isn't there.
  static const _syntheticSize = Size(96, 34);

  final Size collapsedSize;
  final Size expandedSize;
  final double top;

  /// Dead space kept clear at the top of the open island.
  ///
  /// On a Dynamic Island phone this is the cutout's own height: the sensors
  /// are opaque hardware, so anything drawn behind them is simply invisible.
  /// The island grows *downward* past the cutout and puts its content below
  /// it — which is what the real one does, and why it is the only shape in
  /// the app that gets to overlap the status bar.
  final double contentInset;

  factory _IslandGeometry.of(BuildContext context, {required String message}) {
    final media = MediaQuery.of(context);
    final hasHardwareIsland = media.viewPadding.top >= _hardwareTopInset;

    final collapsed = hasHardwareIsland ? _hardwareSize : _syntheticSize;
    final top = hasHardwareIsland ? _hardwareTop : media.viewPadding.top + 8;
    final contentInset = hasHardwareIsland ? _hardwareSize.height : 0.0;

    // Leaves a margin either side so the open island never runs to the screen
    // edge, where the corner radius would crop it.
    final maxWidth = media.size.width - 32;
    final maxTextWidth = maxWidth - horizontalPadding * 2 - iconSize - iconGap;

    final painter = TextPainter(
      text: TextSpan(text: message, style: textStyle),
      textDirection: Directionality.of(context),
      maxLines: maxLines,
      textScaler: media.textScaler,
    )..layout(maxWidth: math.max(0, maxTextWidth));

    final width = math.min(
      maxWidth,
      painter.width + horizontalPadding * 2 + iconSize + iconGap,
    );
    // The row of content, before the sensor area is accounted for.
    final contentHeight = math.max(
      collapsed.height,
      painter.height + verticalPadding * 2,
    );

    return _IslandGeometry(
      collapsedSize: collapsed,
      expandedSize: Size(width, contentInset + contentHeight),
      top: top,
      contentInset: contentInset,
    );
  }
}
