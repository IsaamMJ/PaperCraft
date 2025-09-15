import '../../domain/entities/user_entity.dart';
import '../../domain/entities/user_role.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? tenantId;
  final String role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.tenantId,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  UserEntity toEntity() => UserEntity(
    id: id,
    email: email,
    fullName: fullName,
    tenantId: tenantId,
    role: UserRole.fromString(role),
    isActive: isActive,
    lastLoginAt: lastLoginAt,
    createdAt: createdAt,
  );

  factory UserModel.fromDatabase(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] as String,
      email: data['email'] as String,
      fullName: data['full_name'] as String? ?? '',
      tenantId: data['tenant_id'] as String?,
      role: data['role'] as String,
      isActive: data['is_active'] as bool,
      lastLoginAt: data['last_login_at'] != null
          ? DateTime.parse(data['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}