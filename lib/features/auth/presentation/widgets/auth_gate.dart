import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../versus/presentation/pages/versus_page.dart';
import '../../controllers/auth_controller.dart';
import '../pages/auth_page.dart';

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
          : const VersusPage(),
      error: (error, _) => AuthPage(onGoogleSignIn: signIn),
      loading: () => AuthPage(onGoogleSignIn: signIn, isLoading: true),
    );
  }
}
