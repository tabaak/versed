import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shows the staged photo in the same 4:5 frame the arena uses, so the user
/// sees exactly what will be cropped away before entering.
class FitPreview extends StatelessWidget {
  const FitPreview({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'Your fit, ready to enter the arena',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('The arena crops fits to 4:5.', style: AppTextStyles.meta),
      ],
    );
  }
}
