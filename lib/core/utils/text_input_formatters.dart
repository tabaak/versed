import 'package:flutter/services.dart';

/// Forces typed text to lowercase as it is entered.
///
/// Handles are stored lowercase — the database check constraint rejects
/// anything else — so the field corrects the user rather than scolding them.
class LowercaseTextInputFormatter extends TextInputFormatter {
  const LowercaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lowered = newValue.text.toLowerCase();
    if (lowered == newValue.text) return newValue;

    return newValue.copyWith(text: lowered);
  }
}
