import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_island.dart';
import '../../controllers/my_fits_controller.dart';
import '../../controllers/saved_fits_controller.dart';
import '../../models/fit.dart';
import '../../services/fit_export_service.dart';
import '../../services/fit_service.dart';
import '../widgets/fit_image.dart';
import '../widgets/fit_viewer_details.dart';
import '../widgets/fit_viewer_route.dart';

/// What the overflow menu can return. Which of the destructive two is offered
/// depends on whether the fit is yours.
enum _ViewerMenuAction { saveToGallery, retire, report }

/// A single fit, full size, over a darkened app.
///
/// Opened from a grid tile: the photo zooms up out of the tile it was tapped
/// on the way an app opens from its icon, which is why this is a transparent
/// route around a Hero rather than a page that slides in.
class FitViewerPage extends ConsumerStatefulWidget {
  const FitViewerPage({
    required this.fit,
    required this.heroTag,
    required this.isOwn,
    this.onOwnerTap,
    super.key,
  });

  /// Pushes the viewer for [fit].
  ///
  /// [heroTag] must match the tag on the tile that was tapped, or the photo
  /// fades in instead of zooming. [isOwn] decides both whether the owner's
  /// handle is worth showing and what the overflow menu can offer.
  ///
  /// [onOwnerTap] makes that handle a way through to whoever posted the fit.
  /// The callback comes from the caller rather than being built here because
  /// the profile is another feature's screen, and the fits feature has no
  /// business importing it.
  static Future<void> open(
    BuildContext context, {
    required Fit fit,
    required Object heroTag,
    required bool isOwn,
    VoidCallback? onOwnerTap,
  }) {
    return Navigator.of(context).push<void>(
      FitViewerRoute<void>(
        builder: (_) => FitViewerPage(
          fit: fit,
          heroTag: heroTag,
          isOwn: isOwn,
          onOwnerTap: onOwnerTap,
        ),
      ),
    );
  }

  final Fit fit;
  final Object heroTag;

  /// True when the signed-in user owns the fit — i.e. it came from their own
  /// grid rather than their saved one.
  final bool isOwn;

  /// Opens the owner's profile. Null leaves the handle as plain text.
  final VoidCallback? onOwnerTap;

  @override
  ConsumerState<FitViewerPage> createState() => _FitViewerPageState();
}

class _FitViewerPageState extends ConsumerState<FitViewerPage> {
  /// How far the photo has been dragged down, in logical pixels. Fades the
  /// backdrop as it grows, so a half-committed swipe already shows the grid
  /// coming back.
  double _dragOffset = 0;
  bool _isSharing = false;
  bool _isSavingToGallery = false;

  /// Past this the drag counts as a dismissal on release.
  static const _dismissThreshold = 110.0;
  static const _backdropOpacity = 0.94;

  double get _dragProgress => (_dragOffset / 260).clamp(0.0, 1.0);

  void _close() => Navigator.of(context).pop();

  void _handleDragUpdate(DragUpdateDetails details) {
    // Downward only: dragging up would lift the photo off the tile it has to
    // fly back into.
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final flung = details.velocity.pixelsPerSecond.dy > 700;
    if (flung || _dragOffset > _dismissThreshold) {
      _close();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  Future<void> _toggleSave() async {
    final failure = await ref
        .read(savedFitsControllerProvider.notifier)
        .toggleSave(widget.fit);

    if (!mounted || failure == null) return;
    AppIsland.error(context: context, message: failure);
  }

  Future<void> _share(Rect? origin) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      await ref
          .read(fitExportServiceProvider)
          .shareFit(widget.fit, origin: origin);
    } catch (error) {
      if (mounted) {
        AppIsland.error(context: context, message: describeError(error));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// The overflow menu. Keeping a copy is offered either way; the destructive
  /// half depends on whose fit it is — retiring is the owner's to do, and
  /// reporting is only ever someone else's.
  Future<void> _openMenu() async {
    final action = await AppModal.showActionSheet<_ViewerMenuAction>(
      context: context,
      title: widget.isOwn
          ? 'Your fit'
          : widget.fit.ownerHandle == null
          ? 'Saved fit'
          : "${widget.fit.ownerHandle}'s fit",
      actions: [
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context).pop(_ViewerMenuAction.saveToGallery),
          child: const Text('Save to gallery'),
        ),
        if (widget.isOwn)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_ViewerMenuAction.retire),
            child: const Text('Retire fit'),
          )
        else
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_ViewerMenuAction.report),
            child: const Text('Report fit'),
          ),
      ],
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _ViewerMenuAction.saveToGallery:
        await _saveToGallery();
      case _ViewerMenuAction.retire:
        await _confirmRetire();
      case _ViewerMenuAction.report:
        await _reportFit();
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSavingToGallery) return;
    setState(() => _isSavingToGallery = true);

    try {
      final failure = await ref
          .read(fitExportServiceProvider)
          .saveToGallery(widget.fit);

      if (!mounted) return;
      if (failure == null) {
        AppIsland.success(context: context, message: 'Saved to your gallery.');
      } else {
        AppIsland.error(context: context, message: failure);
      }
    } catch (error) {
      if (mounted) {
        AppIsland.error(context: context, message: describeError(error));
      }
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  Future<void> _confirmRetire() async {
    await AppModal.showActionSheet<void>(
      context: context,
      title: 'Retire this fit?',
      message:
          'It leaves the arena for good. Battles it already fought still '
          'count for the fits it faced.',
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            _retire();
          },
          child: const Text('Retire fit'),
        ),
      ],
    );
  }

  /// Same flow as the arena's report: pick a reason, then send it. The fit
  /// stays where it is — reports are counted, not acted on one at a time.
  Future<void> _reportFit() async {
    final handle = widget.fit.ownerHandle;

    final reason = await AppModal.showActionSheet<FitReportReason>(
      context: context,
      title: handle == null ? 'Report this fit' : "Report $handle's fit",
      message: 'Reported fits leave the arena once enough people agree.',
      actions: [
        for (final reason in FitReportReason.values)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(reason),
            child: Text(reason.label),
          ),
      ],
    );

    if (reason == null || !mounted) return;

    try {
      await ref
          .read(fitServiceProvider)
          .report(fitId: widget.fit.id, reason: reason);

      if (!mounted) return;
      AppIsland.success(context: context, message: 'Reported. Thanks.');
    } catch (error) {
      if (!mounted) return;
      AppIsland.error(context: context, message: describeError(error));
    }
  }

  Future<void> _retire() async {
    try {
      await ref.read(myFitsControllerProvider.notifier).deleteFit(widget.fit);
      if (!mounted) return;

      // The toast lives in the root overlay, so it outlives this page and is
      // still on screen once the grid is back.
      AppIsland.success(context: context, message: 'Fit retired.');
      _close();
    } catch (error) {
      if (!mounted) return;
      AppIsland.error(context: context, message: describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaved = ref.watch(isFitSavedProvider(widget.fit.id));

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: ColoredBox(
              color: AppColors.canvas.withValues(
                alpha: _backdropOpacity * (1 - _dragProgress * 0.55),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Column(
              children: [
                _ViewerTopBar(onClose: _close, onMenu: _openMenu),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _handleDragUpdate,
                    onVerticalDragEnd: _handleDragEnd,
                    onTap: _close,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Hero(
                            tag: widget.heroTag,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FitImage(
                                imagePath: widget.fit.imagePath,
                                semanticLabel: widget.isOwn
                                    ? 'Your fit'
                                    : '${widget.fit.ownerHandle ?? 'Someone'}'
                                          "'s fit",
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: FitViewerDetails(
                    fit: widget.fit,
                    showOwner: !widget.isOwn,
                    isSaved: isSaved,
                    isSharing: _isSharing,
                    onToggleSave: _toggleSave,
                    onShare: _share,
                    onOwnerTap: widget.onOwnerTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Close on the left, overflow on the right — nothing between them, so the
/// photo stays the only thing in the middle of the screen.
class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({required this.onClose, required this.onMenu});

  final VoidCallback onClose;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppIconButton(
            icon: CupertinoIcons.xmark,
            onPressed: onClose,
            semanticLabel: 'Close',
            size: 40,
            iconSize: 20,
            backgroundColor: AppColors.surface,
            haptic: false,
          ),
          AppIconButton(
            icon: CupertinoIcons.ellipsis,
            onPressed: () {
              HapticFeedback.selectionClick();
              onMenu();
            },
            semanticLabel: 'More options',
            size: 40,
            iconSize: 20,
            backgroundColor: AppColors.surface,
            haptic: false,
          ),
        ],
      ),
    );
  }
}
