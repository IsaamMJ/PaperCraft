import '../../domain/entities/grade_entity.dart';

class GradeModel extends GradeEntity {
  const GradeModel({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.level,
    super.section,
    required super.isActive,
    required super.createdAt,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
      section: json['section'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'level': level,
      'section': section,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GradeEntity toEntity() {
    return GradeEntity(
      id: id,
      tenantId: tenantId,
      name: name,
      level: level,
      section: section,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJsonForInsert() {
    return {
      'tenant_id': tenantId,
      'name': name,
      'level': level,
      'section': section,
      'is_active': isActive,
      // Omit 'id' and 'created_at'
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'name': name,
      'level': level,
      'section': section,
      'is_active': isActive,
      // Omit 'id', 'tenant_id', 'created_at'
    };
  }

  factory GradeModel.fromEntity(GradeEntity entity) {
    return GradeModel(
      id: entity.id,
      tenantId: entity.tenantId,
      name: entity.name,
      level: entity.level,
      section: entity.section,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
}
