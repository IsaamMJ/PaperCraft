// domain/entities/user_permissions_entity.dart
import 'package:equatable/equatable.dart';

class UserPermissionsEntity extends Equatable {
  final String id;
  final String userId;
  final String tenantId;
  final List<String>? subjectIds; // null means all subjects allowed
  final List<int>? gradeLevels; // null means all grades allowed
  final bool canCreatePapers;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPermissionsEntity({
    required this.id,
    required this.userId,
    required this.tenantId,
    this.subjectIds,
    this.gradeLevels,
    required this.canCreatePapers,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if user can access a specific subject
  bool canAccessSubject(String subjectId) {
    if (subjectIds == null) return true; // null means all subjects
    return subjectIds!.contains(subjectId);
  }

  /// Check if user can access a specific grade level
  bool canAccessGradeLevel(int gradeLevel) {
    if (gradeLevels == null) return true; // null means all grades
    return gradeLevels!.contains(gradeLevel);
  }

  /// Check if user has any restrictions
  bool get hasRestrictions {
    return subjectIds != null || gradeLevels != null;
  }

  factory UserPermissionsEntity.fromJson(Map<String, dynamic> json) {
    return UserPermissionsEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      subjectIds: (json['subject_ids'] as List<dynamic>?)?.cast<String>(),
      gradeLevels: (json['grade_levels'] as List<dynamic>?)?.cast<int>(),
      canCreatePapers: json['can_create_papers'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'subject_ids': subjectIds,
      'grade_levels': gradeLevels,
      'can_create_papers': canCreatePapers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    tenantId,
    subjectIds,
    gradeLevels,
    canCreatePapers,
    createdAt,
    updatedAt,
  ];
}