import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Result of the debounced handle lookup.
enum HandleAvailability { idle, checking, available, taken }

/// One-line feedback under the handle field: validation error, lookup
/// progress, or confirmation that the handle is free.
class HandleAvailabilityHint extends StatelessWidget {
  const HandleAvailabilityHint({
    required this.availability,
    required this.handle,
    this.error,
    super.key,
  });

  final HandleAvailability availability;
  final String handle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error != null) {
      return _Hint(message: error, color: AppColors.error);
    }

    return switch (availability) {
      HandleAvailability.idle => const SizedBox(height: 18),
      HandleAvailability.checking => const _Hint(
        message: 'Checking…',
        color: AppColors.textSecondary,
      ),
      HandleAvailability.available => _Hint(
        message: '@$handle is free.',
        color: AppColors.success,
      ),
      HandleAvailability.taken => _Hint(
        message: '@$handle is taken.',
        color: AppColors.error,
      ),
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.meta.copyWith(color: color),
        ),
      ),
    );
  }
}
