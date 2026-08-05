import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The circular profile photo, falling back to the first letter of the name
/// whenever there is no image — or the image fails to load.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    this.url,
    this.bytes,
    this.size = 72,
    super.key,
  });

  final String name;
  final String? url;

  /// A photo picked on device but not yet uploaded. Wins over [url], so the
  /// edit page can preview what is about to be saved.
  final Uint8List? bytes;

  final double size;

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final url = this.url;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.elevatedSurface,
        shape: BoxShape.circle,
      ),
      child: switch ((bytes, url)) {
        (final Uint8List bytes, _) => Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        (_, final String url) => Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _Monogram(initial: _initial, size: size),
        ),
        _ => _Monogram(initial: _initial, size: size),
      },
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: AppTextStyles.monogram.copyWith(
        color: AppColors.textPrimary,
        // Keeps the letter proportional whatever size the avatar is drawn at.
        fontSize: size * 0.39,
      ),
    );
  }
}
