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
  final bool hasCompletedOnboarding;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.tenantId,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
    this.hasCompletedOnboarding = false,
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
    hasCompletedOnboarding: hasCompletedOnboarding,
  );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      tenantId: json['tenant_id'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      // Check is_onboarded (preferred) or fallback to has_completed_onboarding for backward compatibility
      hasCompletedOnboarding: json['is_onboarded'] as bool? ??
                              json['has_completed_onboarding'] as bool? ??
                              false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'tenant_id': tenantId,
    'role': role,
    'is_active': isActive,
    'last_login_at': lastLoginAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'has_completed_onboarding': hasCompletedOnboarding,
  };
}