import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expand;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_isEnabled && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  Future<void> _handleTap() async {
    if (!_isEnabled) return;
    await HapticFeedback.heavyImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final button = Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
        onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
        onTapCancel: _isEnabled ? () => _setPressed(false) : null,
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: !_isEnabled
                ? 0.4
                : _isPressed
                ? 0.85
                : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 44),
              padding: EdgeInsets.symmetric(
                horizontal: isPrimary ? 32 : 24,
                vertical: isPrimary ? 14 : 12,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.accent : AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
                border: isPrimary
                    ? null
                    : Border.all(
                        color: AppColors.textPrimary.withValues(
                          alpha: _isPressed ? 1 : 0.4,
                        ),
                      ),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.button.copyWith(
                  color: isPrimary ? AppColors.onAccent : AppColors.textPrimary,
                  fontSize: isPrimary ? 17 : 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
