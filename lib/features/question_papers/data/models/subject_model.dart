// features/question_papers/data/models/subject_model.dart
import '../../domain/entities/subject_entity.dart';

class SubjectModel extends SubjectEntity {
  const SubjectModel({
    required super.id,
    required super.tenantId,
    required super.catalogSubjectId,
    required super.name,
    super.description,
    super.minGrade,
    super.maxGrade,
    required super.isActive,
    required super.createdAt,
  });

  /// Parse from JOIN query result (subjects + subject_catalog)
  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      catalogSubjectId: json['catalog_subject_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      minGrade: json['min_grade'] as int?,
      maxGrade: json['max_grade'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'catalog_subject_id': catalogSubjectId,
      'name': name,
      'description': description,
      'min_grade': minGrade,
      'max_grade': maxGrade,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SubjectEntity toEntity() {
    return SubjectEntity(
      id: id,
      tenantId: tenantId,
      catalogSubjectId: catalogSubjectId,
      name: name,
      description: description,
      minGrade: minGrade,
      maxGrade: maxGrade,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory SubjectModel.fromEntity(SubjectEntity entity) {
    return SubjectModel(
      id: entity.id,
      tenantId: entity.tenantId,
      catalogSubjectId: entity.catalogSubjectId,
      name: entity.name,
      description: entity.description,
      minGrade: entity.minGrade,
      maxGrade: entity.maxGrade,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}