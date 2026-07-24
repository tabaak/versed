import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../../../profile/controllers/profile_controller.dart';
import '../../../profile/presentation/pages/choose_handle_page.dart';
import '../../controllers/auth_controller.dart';
import '../pages/auth_page.dart';

/// Decides what a launch lands on: sign-in, the pick-a-handle step, or the app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    void signIn() {
      ref.read(authControllerProvider.notifier).signInWithGoogle();
    }

    return authState.when(
      data: (user) => user == null
          ? AuthPage(onGoogleSignIn: signIn)
          : const _ProfileGate(),
      error: (error, _) => AuthPage(onGoogleSignIn: signIn),
      loading: () => AuthPage(onGoogleSignIn: signIn, isLoading: true),
    );
  }
}

/// Google sign-in provides no handle, so a signed-in user without one is held
/// here until they pick one. Every fit in the arena can then name an owner.
class _ProfileGate extends ConsumerWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(profileControllerProvider);

    return summary.when(
      loading: () => const _GateLoader(),
      error: (error, _) => CupertinoPageScaffold(
        backgroundColor: AppColors.canvas,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: 'Could not load your profile',
              message: describeError(error),
              actionLabel: 'Try again',
              onAction: () =>
                  ref.read(profileControllerProvider.notifier).refresh(),
            ),
          ),
        ),
      ),
      data: (data) {
        // Null while the auth state and the profile query are still settling.
        if (data == null) return const _GateLoader();
        if (data.profile.needsUsername) return const ChooseHandlePage();
        return const HomeShell();
      },
    );
  }
}

class _GateLoader extends StatelessWidget {
  const _GateLoader();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}
