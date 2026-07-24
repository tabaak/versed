import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_isEnabled && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  void _handleTap() {
    if (!_isEnabled) return;
    HapticFeedback.mediumImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.isLoading
          ? 'Signing in with Google'
          : 'Sign in with Google',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _isEnabled ? (_) => _setPressed(true) : null,
        onTapUp: _isEnabled ? (_) => _setPressed(false) : null,
        onTapCancel: _isEnabled ? () => _setPressed(false) : null,
        onTap: _handleTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: !_isEnabled
              ? 0.45
              : _isPressed
              ? 0.86
              : 1,
          child: Container(
            height: 52,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.googleButtonStroke),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Image(
                    image: AssetImage('assets/branding/google_g.png'),
                    width: 20,
                    height: 20,
                  ),
                ),
                if (widget.isLoading)
                  const CupertinoActivityIndicator(
                    color: AppColors.googleButtonText,
                  )
                else
                  const Text(
                    'Sign in with Google',
                    style: AppTextStyles.googleButton,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
