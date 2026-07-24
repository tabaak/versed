import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/text_input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../controllers/profile_controller.dart';
import '../widgets/handle_availability_hint.dart';

/// Blocking step after the first sign-in: Google gives no handle, so the user
/// picks one before reaching the arena.
class ChooseHandlePage extends ConsumerStatefulWidget {
  const ChooseHandlePage({super.key});

  @override
  ConsumerState<ChooseHandlePage> createState() => _ChooseHandlePageState();
}

class _ChooseHandlePageState extends ConsumerState<ChooseHandlePage> {
  static const _debounce = Duration(milliseconds: 400);

  final _controller = TextEditingController();

  Timer? _checkTimer;
  HandleAvailability _availability = HandleAvailability.idle;
  String? _error;
  bool _isSubmitting = false;

  /// Guards against a slow availability response landing after a newer one.
  int _checkGeneration = 0;

  String get _value => _controller.text.trim();

  bool get _canSubmit =>
      !_isSubmitting &&
      usernameError(_value) == null &&
      _availability != HandleAvailability.taken;

  @override
  void dispose() {
    _checkTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String raw) {
    _checkTimer?.cancel();
    final value = raw.trim();

    setState(() {
      _error = null;
      _availability = HandleAvailability.idle;
    });

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
      // A failed lookup is not a failed handle; let the submit attempt decide.
      setState(() => _availability = HandleAvailability.idle);
    }
  }

  Future<void> _submit() async {
    final localError = usernameError(_value);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final failure = await ref
        .read(profileControllerProvider.notifier)
        .chooseUsername(_value);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = failure;
      if (failure != null) _availability = HandleAvailability.taken;
    });
    // On success the auth gate swaps this page out for the app shell.
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VERSED', style: AppTextStyles.wordmark),
              const SizedBox(height: 40),
              const Text('Claim your handle', style: AppTextStyles.screenTitle),
              const SizedBox(height: 8),
              const Text(
                'This is how the arena knows your fits. Lowercase letters, '
                'numbers and underscores.',
                style: AppTextStyles.secondaryBody,
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _controller,
                placeholder: 'handle',
                autofocus: true,
                enabled: !_isSubmitting,
                semanticLabel: 'Handle',
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onChanged: _handleChanged,
                onSubmitted: (_) => _canSubmit ? _submit() : null,
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
                handle: _value,
                error: _error,
              ),
              const Spacer(),
              AppButton(
                label: _isSubmitting ? 'Claiming…' : 'Continue',
                onPressed: _canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
