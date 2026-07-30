import 'dart:io';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns an exception into a short sentence fit for a toast.
///
/// Database functions raise with explicit SQLSTATE codes, so the common,
/// expected failures get a written message instead of leaking Postgres prose.
String describeError(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '28000' => 'Sign in again to continue.',
      '42501' => 'You are not allowed to do that.',
      '23505' => 'That has already been recorded.',
      '22023' => 'That fit is no longer available.',
      _ => error.message,
    };
  }

  if (error is StorageException) {
    return error.message;
  }

  if (error is AuthException) {
    return error.message;
  }

  if (error is SocketException || error is HttpException) {
    return 'No connection. Check your network and try again.';
  }

  // Only reachable in development: a plugin added since the last full build
  // has no native half registered yet, and a hot reload cannot add one. Said
  // plainly here rather than left to look like a server failure.
  if (error is MissingPluginException) {
    return 'Rebuild the app — a plugin was added since it was last built.';
  }

  if (error is PlatformException) {
    return error.message ?? 'Something went wrong. Try again.';
  }

  return 'Something went wrong. Try again.';
}
