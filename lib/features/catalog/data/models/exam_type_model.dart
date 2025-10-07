// features/question_papers/data/models/exam_type_model.dart
import '../../domain/entities/exam_type_entity.dart';

class ExamTypeModel extends ExamTypeEntity {
  const ExamTypeModel({
    required super.id,
    required super.tenantId,
    required super.subjectId,  // ADDED
    required super.name,
    super.description,
    super.durationMinutes,
    super.totalMarks,
    super.totalSections,
    super.sections,
    super.isActive,
    this.createdAt,
  });

  final DateTime? createdAt;

  factory ExamTypeModel.fromJson(Map<String, dynamic> json) {
    List<ExamSectionEntity> parsedSections = [];

    if (json['sections'] != null && json['sections'] is List) {
      parsedSections = (json['sections'] as List<dynamic>)
          .map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
          .toList();
    }

    return ExamTypeModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      subjectId: json['subject_id'] as String,  // ADDED
      name: json['name'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      totalMarks: json['total_marks'] as int?,
      totalSections: json['total_sections'] as int?,
      sections: parsedSections,
      isActive: json['is_active'] as bool? ?? true,  // ADDED
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'subject_id': subjectId,  // ADDED
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'total_marks': totalMarks,
      'total_sections': totalSections,
      'sections': sections.map((s) => s.toJson()).toList(),
      'is_active': isActive,  // ADDED
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ExamTypeEntity toEntity() {
    return ExamTypeEntity(
      id: id,
      tenantId: tenantId,
      subjectId: subjectId,  // ADDED
      name: name,
      description: description,
      durationMinutes: durationMinutes,
      totalMarks: totalMarks,
      totalSections: totalSections,
      sections: sections,
      isActive: isActive,  // ADDED
    );
  }

  factory ExamTypeModel.fromEntity(ExamTypeEntity entity) {
    return ExamTypeModel(
      id: entity.id,
      tenantId: entity.tenantId,
      subjectId: entity.subjectId,  // ADDED
      name: entity.name,
      description: entity.description,
      durationMinutes: entity.durationMinutes,
      totalMarks: entity.totalMarks,
      totalSections: entity.totalSections,
      sections: entity.sections,
      isActive: entity.isActive,  // ADDED
      createdAt: null,
    );
  }
}