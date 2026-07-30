import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_island.dart';
import '../../../fits/models/fit_genre.dart';
import '../../controllers/upload_controller.dart';
import '../widgets/fit_cropper.dart';
import '../widgets/genre_picker.dart';

/// Submits an outfit photo into the arena.
class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  Future<void> _choosePhoto() async {
    final source = await AppModal.showActionSheet<ImageSource>(
      context: context,
      title: 'Add a fit',
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          child: const Text('Take a photo'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          child: const Text('Choose from library'),
        ),
      ],
    );

    if (source == null || !mounted) return;

    final failure = await ref
        .read(uploadControllerProvider.notifier)
        .pick(source);

    if (!mounted || failure == null) return;
    AppIsland.error(context: context, message: failure);
  }

  void _setCrop(Rect crop) {
    ref.read(uploadControllerProvider.notifier).setCrop(crop);
  }

  void _selectGenre(FitGenre genre) {
    ref.read(uploadControllerProvider.notifier).selectGenre(genre);
  }

  Future<void> _submit() async {
    final failure = await ref.read(uploadControllerProvider.notifier).submit();

    if (!mounted) return;
    if (failure == null) {
      AppIsland.success(context: context, message: 'Your fit is in the arena.');
    } else {
      AppIsland.error(context: context, message: failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadControllerProvider);
    final picked = state.picked;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('VERSED', style: AppTextStyles.wordmark),
        border: null,
        // The shell keeps every tab alive at once, so each tab's bar would
        // otherwise claim the same nav-bar hero tag and collide the moment a
        // route is pushed.
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: picked == null
              ? AppEmptyState(
                  icon: CupertinoIcons.camera,
                  title: 'Upload your fit',
                  message:
                      'Drop a photo of your outfit and let the arena decide.',
                  actionLabel: 'Choose a photo',
                  onAction: _choosePhoto,
                )
              : Column(
                  children: [
                    Expanded(
                      child: FitCropper(
                        picked: picked,
                        enabled: !state.isUploading,
                        onCropChanged: _setCrop,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GenrePicker(
                      selected: state.genre,
                      enabled: !state.isUploading,
                      onSelected: _selectGenre,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: state.isUploading
                          ? 'Entering…'
                          : 'Enter the arena',
                      onPressed: state.canSubmit ? _submit : null,
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Choose another',
                      variant: AppButtonVariant.secondary,
                      onPressed: state.isUploading ? null : _choosePhoto,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
