import 'package:supabase_flutter/supabase_flutter.dart';

class AuthModel {
  const AuthModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
  });

  factory AuthModel.fromUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};

    return AuthModel(
      id: user.id,
      email: user.email,
      displayName:
          metadata['full_name'] as String? ??
          metadata['name'] as String? ??
          user.email,
      avatarUrl: metadata['avatar_url'] as String?,
    );
  }

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  AuthModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) {
    return AuthModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthModel &&
            other.id == id &&
            other.email == email &&
            other.displayName == displayName &&
            other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(id, email, displayName, avatarUrl);

  @override
  String toString() {
    return 'AuthModel(id: $id, email: $email, displayName: $displayName, '
        'avatarUrl: $avatarUrl)';
  }
}
