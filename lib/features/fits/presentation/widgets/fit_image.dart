import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Renders a fit photo from its storage path.
///
/// Resolving the public URL lives here so pages and grids never have to reach
/// for the storage service themselves.
class FitImage extends ConsumerWidget {
  const FitImage({required this.imagePath, this.semanticLabel, super.key});

  final String imagePath;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(storageServiceProvider).fitImageUrl(imagePath);

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _FitImagePlaceholder(
          child: CupertinoActivityIndicator(radius: 10),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const _FitImagePlaceholder(
          child: Icon(
            CupertinoIcons.photo,
            size: 28,
            color: AppColors.textTertiary,
          ),
        );
      },
    );
  }
}

class _FitImagePlaceholder extends StatelessWidget {
  const _FitImagePlaceholder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(child: child),
    );
  }
}
