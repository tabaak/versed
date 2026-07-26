import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/text_input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_view.dart';
import '../../../../core/widgets/app_navigation_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../controllers/profile_controller.dart';
import '../widgets/handle_availability_hint.dart';

/// Edits the two identity fields the user owns: display name and handle.
///
/// Pops with `true` once the profile row has been saved, so the caller can
/// confirm the change.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({
    required this.initialDisplayName,
    required this.initialUsername,
    super.key,
  });

  final String? initialDisplayName;
  final String? initialUsername;

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

  /// Guards against a slow availability response landing after a newer one.
  int _checkGeneration = 0;

  String get _handle => _handleController.text.trim();

  String get _name => _nameController.text.trim();

  String get _initialHandle => widget.initialUsername ?? '';

  String get _initialName => widget.initialDisplayName?.trim() ?? '';

  bool get _hasChanges => _handle != _initialHandle || _name != _initialName;

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
        .updateProfile(username: _handle, displayName: _name);

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
