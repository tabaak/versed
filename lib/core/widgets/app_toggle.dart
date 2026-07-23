import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class AppToggleSwitch extends StatelessWidget {
  const AppToggleSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  Future<void> _handleChanged(bool newValue) async {
    await HapticFeedback.selectionClick();
    onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: semanticLabel,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged == null ? null : _handleChanged,
        activeTrackColor: AppColors.textSecondary,
        inactiveTrackColor: AppColors.elevatedSurface,
        thumbColor: AppColors.textPrimary,
      ),
    );
  }
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  Future<void> _handleChanged(bool? newValue) async {
    if (newValue == null) return;
    await HapticFeedback.selectionClick();
    onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: onChanged != null,
      label: semanticLabel,
      child: CupertinoCheckbox(
        value: value,
        onChanged: onChanged == null ? null : _handleChanged,
        activeColor: AppColors.accent,
        checkColor: AppColors.onAccent,
        side: const BorderSide(color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
