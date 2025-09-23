import 'user_role.dart';

class UserEntity {
  final String id;
  final String email;
  final String fullName;
  final String? tenantId;
  final UserRole role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    this.tenantId,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  // Business logic
  bool get isValid => id.isNotEmpty && email.isNotEmpty && tenantId != null;
  bool get isAdmin => role == UserRole.admin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isBlocked => role == UserRole.blocked;
  bool get canCreatePapers => isActive && (isAdmin || isTeacher);
  bool get canManageUsers => isActive && isAdmin;
  String get displayName => fullName.isNotEmpty ? fullName : email.split('@').first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}