import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/text_input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_image_cropper.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/app_notification.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../upload/models/upload_state.dart';
import '../../../upload/services/image_pick_service.dart';
import '../../controllers/profile_controller.dart';
import '../widgets/handle_availability_hint.dart';
import '../widgets/profile_avatar.dart';

/// Edits the two identity fields the user owns: display name and handle.
///
/// Pops with `true` once the profile row has been saved, so the caller can
/// confirm the change.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({
    required this.initialDisplayName,
    required this.initialUsername,
    this.initialAvatarUrl,
    super.key,
  });

  final String? initialDisplayName;
  final String? initialUsername;
  final String? initialAvatarUrl;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const _debounce = Duration(milliseconds: 400);

  late final TextEditingController _nameController;
  late final TextEditingController _handleController;

  Timer? _checkTimer;
  HandleAvailability _availability = HandleAvailability.idle;
  String? _handleError;
  String? _nameError;
  bool _isSaving = false;

  /// A photo picked on device. It is cropped and uploaded by the save, not by
  /// the picker, so backing out of the page costs nothing.
  PickedFit? _pickedAvatar;

  /// Set by "Remove photo", and cleared again by picking a new one.
  bool _removeAvatar = false;

  /// The square region of [_pickedAvatar] the cropper is showing, in source
  /// pixels. Null until the cropper reports a frame; the controller falls back
  /// to a centered square.
  Rect? _avatarCrop;

  /// Guards against a slow availability response landing after a newer one.
  int _checkGeneration = 0;

  String get _handle => _handleController.text.trim();

  String get _name => _nameController.text.trim();

  String get _initialHandle => widget.initialUsername ?? '';

  String get _initialName => widget.initialDisplayName?.trim() ?? '';

  /// The photo the page is showing: the staged pick, else the saved one
  /// unless it is on its way out.
  String? get _shownAvatarUrl =>
      _removeAvatar ? null : widget.initialAvatarUrl;

  bool get _hasAvatar => _pickedAvatar != null || _shownAvatarUrl != null;

  bool get _hasChanges =>
      _handle != _initialHandle ||
      _name != _initialName ||
      _pickedAvatar != null ||
      _removeAvatar;

  bool get _canSave =>
      !_isSaving &&
      _hasChanges &&
      usernameError(_handle) == null &&
      displayNameError(_name) == null &&
      _availability != HandleAvailability.taken;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _initialName);
    _handleController = TextEditingController(text: _initialHandle);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _showPhotoActions() async {
    if (_isSaving) return;

    await AppModal.showActionSheet<void>(
      context: context,
      title: 'Profile photo',
      message: 'You frame it yourself. It is shown next to your handle.',
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            _pickAvatar(ImageSource.gallery);
          },
          child: const Text('Choose from library'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            _pickAvatar(ImageSource.camera);
          },
          child: const Text('Take photo'),
        ),
        if (_hasAvatar)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _pickedAvatar = null;
                _avatarCrop = null;
                _removeAvatar = true;
              });
            },
            child: const Text('Remove photo'),
          ),
      ],
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await ref.read(imagePickServiceProvider).pick(source);
      // A null pick means the user backed out — not a failure.
      if (picked == null || !mounted) return;

      setState(() {
        _pickedAvatar = picked;
        // A fresh photo is a fresh frame; the cropper reports one on layout.
        _avatarCrop = null;
        _removeAvatar = false;
      });
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context: context, message: describeError(error));
    }
  }

  void _handleNameChanged(String raw) {
    setState(() => _nameError = displayNameError(raw));
  }

  void _handleChanged(String raw) {
    _checkTimer?.cancel();
    final value = raw.trim();

    setState(() {
      _handleError = null;
      _availability = HandleAvailability.idle;
    });

    // The user's own handle is neither free nor taken — it is already theirs.
    if (value == _initialHandle) return;
    if (usernameError(value) != null) return;

    setState(() => _availability = HandleAvailability.checking);
    _checkTimer = Timer(_debounce, () => _checkAvailability(value));
  }

  Future<void> _checkAvailability(String value) async {
    final generation = ++_checkGeneration;

    try {
      final available = await ref
          .read(profileControllerProvider.notifier)
          .isUsernameAvailable(value);

      if (!mounted || generation != _checkGeneration) return;
      setState(() {
        _availability = available
            ? HandleAvailability.available
            : HandleAvailability.taken;
      });
    } catch (_) {
      if (!mounted || generation != _checkGeneration) return;
      // A failed lookup is not a failed handle; let the save attempt decide.
      setState(() => _availability = HandleAvailability.idle);
    }
  }

  Future<void> _save() async {
    final handleError = usernameError(_handle);
    final nameError = displayNameError(_name);
    if (handleError != null || nameError != null) {
      setState(() {
        _handleError = handleError;
        _nameError = nameError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _handleError = null;
      _nameError = null;
    });

    final failure = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          username: _handle,
          displayName: _name,
          avatar: _pickedAvatar,
          avatarCrop: _avatarCrop,
          removeAvatar: _removeAvatar,
        );

    if (!mounted) return;

    if (failure == null) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _handleError = failure;
      if (failure == 'That handle is taken.') {
        _availability = HandleAvailability.taken;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Column(
        children: [
          AppNavigationBar(
            title: 'Edit profile',
            showBrand: false,
            onBack: _isSaving ? null : () => Navigator.of(context).pop(false),
          ),
          Expanded(
            child: AppListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: Column(
                    children: [
                      _AvatarField(
                        picked: _pickedAvatar,
                        avatarUrl: _shownAvatarUrl,
                        name: _name.isEmpty ? _handle : _name,
                        enabled: !_isSaving,
                        onCropChanged: (crop) => _avatarCrop = crop,
                        onTap: _showPhotoActions,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: _hasAvatar ? 'Change photo' : 'Add photo',
                        variant: AppButtonVariant.secondary,
                        expand: false,
                        onPressed: _isSaving ? null : _showPhotoActions,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _FieldLabel('Display name'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _nameController,
                  placeholder: 'Your name',
                  enabled: !_isSaving,
                  semanticLabel: 'Display name',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  onChanged: _handleNameChanged,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(displayNameMaxLength),
                  ],
                ),
                const SizedBox(height: 8),
                _FieldHint(
                  message:
                      _nameError ??
                      'This is what is displayed above your handle. ',
                  isError: _nameError != null,
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Handle'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _handleController,
                  placeholder: 'handle',
                  enabled: !_isSaving,
                  semanticLabel: 'Handle',
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onChanged: _handleChanged,
                  onSubmitted: (_) => _canSave ? _save() : null,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('@', style: AppTextStyles.secondaryBody),
                  ),
                  inputFormatters: [
                    const LowercaseTextInputFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
                    LengthLimitingTextInputFormatter(usernameMaxLength),
                  ],
                ),
                const SizedBox(height: 8),
                HandleAvailabilityHint(
                  availability: _availability,
                  handle: _handle,
                  error: _handleError,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: _isSaving ? 'Saving…' : 'Save changes',
                  onPressed: _canSave ? _save : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The profile photo, in whichever of its two states applies: a staged pick
/// the user can still frame, or the saved one waiting to be replaced.
class _AvatarField extends StatelessWidget {
  const _AvatarField({
    required this.picked,
    required this.avatarUrl,
    required this.name,
    required this.enabled,
    required this.onCropChanged,
    required this.onTap,
  });

  /// How wide the square cropper is drawn. Wide enough to frame against,
  /// short enough that the fields below stay on screen.
  static const _cropperWidth = 240.0;

  final PickedFit? picked;
  final String? avatarUrl;
  final String name;
  final bool enabled;
  final ValueChanged<Rect> onCropChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = this.picked;
    if (picked == null) {
      return GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Profile photo',
          child: ProfileAvatar(name: name, url: avatarUrl, size: 96),
        ),
      );
    }

    return SizedBox(
      width: _cropperWidth,
      child: AppImageCropper(
        bytes: picked.bytes,
        imageWidth: picked.width,
        imageHeight: picked.height,
        aspectRatio: 1,
        circular: true,
        enabled: enabled,
        onCropChanged: onCropChanged,
        semanticLabel: 'Your new photo. Drag or pinch to frame it.',
        caption: 'Drag or pinch to frame. Profiles are cropped to a circle.',
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.sectionTitle);
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: isError,
      child: Text(
        message,
        style: AppTextStyles.meta.copyWith(
          color: isError ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }
}
