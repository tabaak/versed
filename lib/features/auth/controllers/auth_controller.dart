import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_model.dart';
import '../services/auth_service.dart';

class AuthController extends AsyncNotifier<AuthModel?> {
  @override
  FutureOr<AuthModel?> build() {
    final service = ref.watch(authServiceProvider);
    final subscription = service.authStateChanges.listen((authState) {
      state = AsyncData(
        authState.session == null
            ? null
            : AuthModel.fromUser(authState.session!.user),
      );
    });
    ref.onDispose(subscription.cancel);

    final user = service.currentUser;
    return user == null ? null : AuthModel.fromUser(user);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).signOut();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthModel?>(AuthController.new);
