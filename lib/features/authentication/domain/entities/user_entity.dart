
// domain/entities/user_entity.dart
import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;          // Supabase UUID (required)
  final String name;        // Google display name (required)
  final String email;       // Google email (required)
  final String? avatarUrl;  // Profile picture (optional)
  final DateTime createdAt; // Account creation time (required)

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, email, avatarUrl, createdAt];

  // Useful for debugging
  @override
  String toString() {
    return 'UserEntity(id: $id, name: $name, email: $email, avatarUrl: $avatarUrl, createdAt: $createdAt)';
  }

  // Copy method for potential updates
  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Validation method
  bool get isValid {
    return id.isNotEmpty &&
        name.isNotEmpty &&
        email.isNotEmpty &&
        email.contains('@');
  }
}