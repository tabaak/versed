import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon_button.dart';

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    this.title,
    this.leading,
    this.trailing,
    this.onBack,
    this.showBrand = true,
    super.key,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final resolvedLeading =
        leading ??
        (onBack == null
            ? null
            : AppIconButton(
                icon: CupertinoIcons.chevron_back,
                onPressed: onBack,
                semanticLabel: 'Back',
                backgroundColor: AppColors.canvas,
                haptic: false,
              ));

    return ColoredBox(
      color: AppColors.canvas,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showBrand)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'VERSED',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  )
                else if (resolvedLeading != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: resolvedLeading,
                  ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 72),
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.screenTitle.copyWith(fontSize: 17),
                    ),
                  ),
                if (trailing != null)
                  Align(alignment: Alignment.centerRight, child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
