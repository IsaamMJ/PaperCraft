// features/question_papers/data/models/exam_type_model.dart
import '../../domain/entities/exam_type_entity.dart';

class ExamTypeModel extends ExamTypeEntity {
  const ExamTypeModel({
    required super.id,
    required super.tenantId,
    required super.name,
    super.durationMinutes,
    super.totalMarks,
    super.totalQuestions,
    super.sections,
    this.description,
    this.createdAt,
  });

  final String? description;
  final DateTime? createdAt;

  factory ExamTypeModel.fromJson(Map<String, dynamic> json) {
    List<ExamSectionEntity> parsedSections = [];

    if (json['sections'] != null) {
      if (json['sections'] is String) {
        // Handle case where sections might be stored as JSON string
        try {
          final sectionsJson = json['sections'];
          if (sectionsJson is List) {
            parsedSections = (sectionsJson as List<dynamic>)
                .map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          // If parsing fails, leave sections empty
          parsedSections = [];
        }
      } else if (json['sections'] is List) {
        parsedSections = (json['sections'] as List<dynamic>)
            .map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
            .toList();
      }
    }

    return ExamTypeModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      totalMarks: json['total_marks'] as int?,
      totalQuestions: json['total_sections'] as int?, // Note: this maps to total_sections in DB
      sections: parsedSections,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'duration_minutes': durationMinutes,
      'total_marks': totalMarks,
      'total_sections': totalQuestions,
      'sections': sections.map((section) => section.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory ExamTypeModel.fromEntity(ExamTypeEntity entity) {
    return ExamTypeModel(
      id: entity.id,
      tenantId: entity.tenantId,
      name: entity.name,
      durationMinutes: entity.durationMinutes,
      totalMarks: entity.totalMarks,
      totalQuestions: entity.totalQuestions,
      sections: entity.sections,
      description: null,
      createdAt: null,
    );
  }

  ExamTypeEntity toEntity() {
    return ExamTypeEntity(
      id: id,
      tenantId: tenantId,
      name: name,
      durationMinutes: durationMinutes,
      totalMarks: totalMarks,
      totalQuestions: totalQuestions,
      sections: sections,
    );
  }

  ExamTypeModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? description,
    int? durationMinutes,
    int? totalMarks,
    int? totalQuestions,
    List<ExamSectionEntity>? sections,
    DateTime? createdAt,
  }) {
    return ExamTypeModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalMarks: totalMarks ?? this.totalMarks,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      sections: sections ?? this.sections,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}