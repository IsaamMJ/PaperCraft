// features/question_papers/data/models/subject_model.dart
import '../../domain/entities/subject_entity.dart';

class SubjectModel extends SubjectEntity {
  const SubjectModel({
    required super.id,
    required super.tenantId,
    required super.name,
    super.description,
    required super.isActive,
    required super.createdAt,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SubjectEntity toEntity() {
    return SubjectEntity(
      id: id,
      tenantId: tenantId,
      name: name,
      description: description,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory SubjectModel.fromEntity(SubjectEntity entity) {
    return SubjectModel(
      id: entity.id,
      tenantId: entity.tenantId,
      name: entity.name,
      description: entity.description,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}