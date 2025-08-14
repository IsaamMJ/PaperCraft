// Enhanced UserModel
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.avatarUrl,
    required super.createdAt,
  });

  // Add null safety and validation
  factory UserModel.fromSupabaseUser(Map<String, dynamic> json) {
    try {
      final userMetadata = json['user_metadata'] as Map<String, dynamic>? ?? {};

      return UserModel(
        id: json['id'] as String,
        name: userMetadata['name'] as String? ?? 'Unknown User',
        email: json['email'] as String,
        avatarUrl: userMetadata['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } catch (e) {
      throw FormatException('Invalid Supabase user data: $e');
    }
  }
}