import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_skeleton.dart';

/// Widest a fit is ever decoded at, in physical pixels.
///
/// Uploads are capped near this already, but seeded and legacy photos are not:
/// a full-resolution one decodes to tens of megabytes and evicts the rest of
/// the image cache, which is exactly what a warmed matchup cannot afford.
const int fitImageDecodeWidth = 1440;

/// The provider behind every fit photo.
///
/// Anything warming a fit ahead of time must resolve it through this, or it
/// warms a different cache key than [FitImage] later asks for.
ImageProvider fitImageProvider(String url) {
  return ResizeImage(NetworkImage(url), width: fitImageDecodeWidth);
}

/// Renders a fit photo from its storage path.
///
/// Resolving the public URL lives here so pages and grids never have to reach
/// for the storage service themselves.
class FitImage extends ConsumerWidget {
  const FitImage({
    required this.imagePath,
    this.semanticLabel,
    this.phase = 0,
    super.key,
  });

  final String imagePath;
  final String? semanticLabel;

  /// Shimmer offset for the loading skeleton, so two photos side by side do
  /// not sweep in lockstep. See [AppSkeleton.phase].
  final double phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(storageServiceProvider).fitImageUrl(imagePath);

    return Image(
      image: fitImageProvider(url),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      // Skeleton first, then a cross-fade into the photo. An image already in
      // the cache reports `progress == null` on the very first call, so the
      // switcher starts on the photo and nothing flashes.
      loadingBuilder: (context, child, progress) {
        final loaded = progress == null;
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: loaded
              ? KeyedSubtree(key: const ValueKey('photo'), child: child)
              : AppSkeleton(key: const ValueKey('skeleton'), phase: phase),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: AppColors.surface,
          child: Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 28,
              color: AppColors.textTertiary,
            ),
          ),
        );
      },
    );
  }
}
