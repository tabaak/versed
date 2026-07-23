import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppNotificationStatus { neutral, success, error }

enum AppNotificationPosition { top, bottom }

class AppNotification extends StatelessWidget {
  const AppNotification({
    required this.message,
    this.status = AppNotificationStatus.neutral,
    this.onDismiss,
    super.key,
  });

  final String message;
  final AppNotificationStatus status;
  final VoidCallback? onDismiss;

  Color get _statusColor {
    return switch (status) {
      AppNotificationStatus.neutral => AppColors.textPrimary,
      AppNotificationStatus.success => AppColors.success,
      AppNotificationStatus.error => AppColors.error,
    };
  }

  IconData get _statusIcon {
    return switch (status) {
      AppNotificationStatus.neutral => CupertinoIcons.info_circle_fill,
      AppNotificationStatus.success => CupertinoIcons.check_mark_circled_solid,
      AppNotificationStatus.error => CupertinoIcons.exclamationmark_circle_fill,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.canvas.withValues(alpha: 0.8),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(_statusIcon, size: 20, color: _statusColor),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: AppTextStyles.body)),
              if (onDismiss != null)
                CupertinoButton(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  onPressed: onDismiss,
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class AppToast {
  static OverlayEntry show({
    required BuildContext context,
    required String message,
    AppNotificationStatus status = AppNotificationStatus.neutral,
    AppNotificationPosition position = AppNotificationPosition.bottom,
    Duration duration = const Duration(seconds: 3),
  }) {
    late final OverlayEntry entry;
    final viewPadding = MediaQuery.viewPaddingOf(context);

    void dismiss() {
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 16,
          right: 16,
          top: position == AppNotificationPosition.top
              ? viewPadding.top + 12
              : null,
          bottom: position == AppNotificationPosition.bottom
              ? viewPadding.bottom + 16
              : null,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              final direction = position == AppNotificationPosition.top
                  ? -1.0
                  : 1.0;
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * direction * (1 - value)),
                  child: child,
                ),
              );
            },
            child: AppNotification(
              message: message,
              status: status,
              onDismiss: dismiss,
            ),
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(entry);
    Future<void>.delayed(duration, dismiss);
    return entry;
  }

  static OverlayEntry success({
    required BuildContext context,
    required String message,
    AppNotificationPosition position = AppNotificationPosition.bottom,
  }) {
    return show(
      context: context,
      message: message,
      status: AppNotificationStatus.success,
      position: position,
    );
  }

  static OverlayEntry error({
    required BuildContext context,
    required String message,
    AppNotificationPosition position = AppNotificationPosition.top,
  }) {
    return show(
      context: context,
      message: message,
      status: AppNotificationStatus.error,
      position: position,
    );
  }
}
