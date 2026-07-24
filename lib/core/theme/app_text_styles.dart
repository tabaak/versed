import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -1.4,
  );

  static const wordmark = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 3.2,
  );

  static const monogram = TextStyle(
    color: AppColors.onAccent,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  static const matchupDivider = TextStyle(
    color: AppColors.onAccent,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1,
    letterSpacing: 0.4,
  );

  static const googleButton = TextStyle(
    color: AppColors.googleButtonText,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static const screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const secondaryBody = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1,
    letterSpacing: -0.2,
  );

  static const meta = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const tabularMetric = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
