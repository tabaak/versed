// Shared input validation.

/// Mirrors the `profiles_username_format` check constraint in the database:
/// 3-20 characters, lowercase letters, digits and underscores only.
final RegExp usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

const int usernameMinLength = 3;
const int usernameMaxLength = 20;

/// Returns null when [username] is acceptable, otherwise the reason it is not.
///
/// Kept in sync with the database constraint by hand: the check runs client
/// side purely so the user gets a message before a round trip, and the
/// constraint remains the authority.
String? usernameError(String username) {
  if (username.isEmpty) {
    return 'Pick a handle.';
  }
  if (username.length < usernameMinLength) {
    return 'At least $usernameMinLength characters.';
  }
  if (username.length > usernameMaxLength) {
    return 'At most $usernameMaxLength characters.';
  }
  if (!usernamePattern.hasMatch(username)) {
    return 'Lowercase letters, numbers and underscores only.';
  }
  return null;
}
