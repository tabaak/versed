import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The owner and completed-view count revealed along the foot of a contender.
class ContenderMetadata extends StatelessWidget {
  const ContenderMetadata({
    required this.handle,
    required this.viewCount,
    super.key,
  });

  final String? handle;
  final int viewCount;

  @override
  Widget build(BuildContext context) {
    final normalizedHandle = handle?.trim();
    final showHandle = normalizedHandle != null && normalizedHandle.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showHandle)
          Flexible(
            child: _MetadataChip(
              child: Text(
                normalizedHandle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardMetadata,
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(width: 8),
        Semantics(
          label: '$viewCount ${viewCount == 1 ? 'view' : 'views'}',
          child: ExcludeSemantics(
            child: _MetadataChip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.eye,
                    size: 15,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text('$viewCount', style: AppTextStyles.cardMetadata),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}
