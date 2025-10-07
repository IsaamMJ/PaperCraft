// features/assignments/data/models/teacher_grade_assignment_model.dart
import '../../domain/entities/teacher_grade_assignment_entity.dart';

class TeacherGradeAssignmentModel extends TeacherGradeAssignmentEntity {
  const TeacherGradeAssignmentModel({
    required super.id,
    required super.tenantId,
    required super.teacherId,
    required super.gradeId,
    required super.academicYear,
    required super.isActive,
    required super.createdAt,
  });

  factory TeacherGradeAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TeacherGradeAssignmentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      gradeId: json['grade_id'] as String,
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
      'grade_id': gradeId,
      'academic_year': academicYear,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeacherGradeAssignmentEntity toEntity() {
    return TeacherGradeAssignmentEntity(
      id: id,
      tenantId: tenantId,
      teacherId: teacherId,
      gradeId: gradeId,
      academicYear: academicYear,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory TeacherGradeAssignmentModel.fromEntity(TeacherGradeAssignmentEntity entity) {
    return TeacherGradeAssignmentModel(
      id: entity.id,
      tenantId: entity.tenantId,
      teacherId: entity.teacherId,
      gradeId: entity.gradeId,
      academicYear: entity.academicYear,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}