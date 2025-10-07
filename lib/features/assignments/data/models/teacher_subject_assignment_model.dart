// features/assignments/data/models/teacher_subject_assignment_model.dart
import '../../domain/entities/teacher_subject_assignment_entity.dart';

class TeacherSubjectAssignmentModel extends TeacherSubjectAssignmentEntity {
  const TeacherSubjectAssignmentModel({
    required super.id,
    required super.tenantId,
    required super.teacherId,
    required super.subjectId,
    required super.academicYear,
    required super.isActive,
    required super.createdAt,
  });

  factory TeacherSubjectAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TeacherSubjectAssignmentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      academicYear: json['academic_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'academic_year': academicYear,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeacherSubjectAssignmentEntity toEntity() {
    return TeacherSubjectAssignmentEntity(
      id: id,
      tenantId: tenantId,
      teacherId: teacherId,
      subjectId: subjectId,
      academicYear: academicYear,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory TeacherSubjectAssignmentModel.fromEntity(TeacherSubjectAssignmentEntity entity) {
    return TeacherSubjectAssignmentModel(
      id: entity.id,
      tenantId: entity.tenantId,
      teacherId: entity.teacherId,
      subjectId: entity.subjectId,
      academicYear: entity.academicYear,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}