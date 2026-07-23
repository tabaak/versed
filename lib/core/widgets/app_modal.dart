import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

abstract final class AppModal {
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    await HapticFeedback.mediumImpact();

    if (!context.mounted) return null;
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.canvas.withValues(alpha: 0.72),
      builder: (modalContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: false,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: builder(modalContext),
            ),
          ),
        );
      },
    );
  }

  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<CupertinoActionSheetAction> actions,
    String cancelLabel = 'Cancel',
  }) async {
    await HapticFeedback.mediumImpact();

    if (!context.mounted) return null;
    return showCupertinoModalPopup<T>(
      context: context,
      barrierColor: AppColors.canvas.withValues(alpha: 0.72),
      builder: (modalContext) {
        return CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.canvas,
            primaryColor: AppColors.accent,
          ),
          child: CupertinoActionSheet(
            title: title == null ? null : Text(title),
            message: message == null ? null : Text(message),
            actions: actions,
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(modalContext).pop(),
              child: Text(cancelLabel),
            ),
          ),
        );
      },
    );
  }
}
