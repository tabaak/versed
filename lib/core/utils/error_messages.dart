import 'dart:io';

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

  return 'Something went wrong. Try again.';
}
