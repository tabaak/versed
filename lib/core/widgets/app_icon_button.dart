import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class AppIconButton extends StatefulWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.iconSize = 22,
    this.backgroundColor = AppColors.surface,
    this.haptic = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final bool haptic;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null) return;
    if (widget.haptic) await HapticFeedback.heavyImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onPressed == null ? null : (_) => _setPressed(true),
        onTapUp: widget.onPressed == null ? null : (_) => _setPressed(false),
        onTapCancel: widget.onPressed == null ? null : () => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: widget.onPressed == null
                ? 0.35
                : _isPressed
                ? 0.65
                : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isPressed
                    ? AppColors.elevatedSurface
                    : widget.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: AppColors.textPrimary,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
