// features/question_papers/data/models/grade_model.dart
import '../../domain/entities/grade_entity.dart';

class GradeModel extends GradeEntity {
  const GradeModel({
    required super.id,
    required super.tenantId,
    required super.gradeNumber,
    required super.isActive,
    required super.createdAt,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeNumber: json['grade_number'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'grade_number': gradeNumber,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GradeEntity toEntity() {
    return GradeEntity(
      id: id,
      tenantId: tenantId,
      gradeNumber: gradeNumber,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory GradeModel.fromEntity(GradeEntity entity) {
    return GradeModel(
      id: entity.id,
      tenantId: entity.tenantId,
      gradeNumber: entity.gradeNumber,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}