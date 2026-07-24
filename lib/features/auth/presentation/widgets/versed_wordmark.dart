import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class VersedWordmark extends StatelessWidget {
  const VersedWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'VERSED',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('V', style: AppTextStyles.monogram),
          ),
          const SizedBox(width: 12),
          const ExcludeSemantics(
            child: Text('VERSED', style: AppTextStyles.wordmark),
          ),
        ],
      ),
    );
  }
}
