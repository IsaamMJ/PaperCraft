// features/catalog/data/models/subject_catalog_model.dart
import '../../domain/entities/subject_entity.dart';

class SubjectCatalogModel {
  final String id;
  final String name;
  final String? description;
  final int minGrade;
  final int maxGrade;
  final bool isActive;

  const SubjectCatalogModel({
    required this.id,
    required this.name,
    this.description,
    required this.minGrade,
    required this.maxGrade,
    required this.isActive,
  });

  factory SubjectCatalogModel.fromJson(Map<String, dynamic> json) {
    return SubjectCatalogModel(
      id: json['id'] as String,
      // Handle both 'name' and 'subject_name' keys for compatibility
      name: (json['name'] ?? json['subject_name']) as String,
      description: json['description'] as String?,
      minGrade: json['min_grade'] as int,
      maxGrade: json['max_grade'] as int,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'min_grade': minGrade,
      'max_grade': maxGrade,
      'is_active': isActive,
    };
  }

  /// Convert catalog model to subject entity
  SubjectEntity toEntity() {
    return SubjectEntity(
      id: id,
      tenantId: '', // Catalog model doesn't have tenant ID
      catalogSubjectId: id,
      name: name,
      description: description,
      minGrade: minGrade,
      maxGrade: maxGrade,
      isActive: isActive,
      createdAt: DateTime.now(),
    );
  }
}