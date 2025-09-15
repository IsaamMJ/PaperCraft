import 'package:equatable/equatable.dart';

class UserPermissionsEntity extends Equatable {
  final String id;
  final String userId;
  final String tenantId;
  final bool canCreatePapers;
  final bool canApprovePapers;
  final List<String>? subjectIds;
  final List<int>? gradeLevels;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPermissionsEntity({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.canCreatePapers,
    required this.canApprovePapers,
    this.subjectIds,
    this.gradeLevels,
    required this.createdAt,
    required this.updatedAt,
  });

  bool canAccessSubject(String subjectId) {
    if (subjectIds == null) return true; // No restrictions
    return subjectIds!.contains(subjectId);
  }

  bool canAccessGradeLevel(int gradeLevel) {
    if (gradeLevels == null) return true; // No restrictions
    return gradeLevels!.contains(gradeLevel);
  }

  factory UserPermissionsEntity.fromJson(Map<String, dynamic> json) {
    return UserPermissionsEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      canCreatePapers: json['can_create_papers'] as bool? ?? false,
      canApprovePapers: json['can_approve_papers'] as bool? ?? false,
      subjectIds: json['subject_ids'] != null
          ? List<String>.from(json['subject_ids'])
          : null,
      gradeLevels: json['grade_levels'] != null
          ? List<int>.from(json['grade_levels'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tenant_id': tenantId,
      'can_create_papers': canCreatePapers,
      'can_approve_papers': canApprovePapers,
      'subject_ids': subjectIds,
      'grade_levels': gradeLevels,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id, userId, tenantId, canCreatePapers, canApprovePapers,
    subjectIds, gradeLevels, createdAt, updatedAt
  ];
}
