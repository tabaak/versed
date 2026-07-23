import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.semanticLabel,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    super.key,
  });

  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final String? semanticLabel;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      enabled: enabled,
      label: semanticLabel ?? placeholder,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        prefix: prefix,
        suffix: suffix,
        obscureText: obscureText,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        cursorColor: AppColors.accent,
        cursorOpacityAnimates: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        placeholder: placeholder,
        placeholderStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
