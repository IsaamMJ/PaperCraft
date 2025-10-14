// features/catalog/data/models/teacher_pattern_model.dart
import 'dart:convert';

import '../../domain/entities/paper_section_entity.dart';
import '../../domain/entities/teacher_pattern_entity.dart';

/// Data model for teacher pattern (maps to database structure)
class TeacherPatternModel extends TeacherPatternEntity {
  const TeacherPatternModel({
    required super.id,
    required super.tenantId,
    required super.teacherId,
    required super.subjectId,
    required super.name,
    required super.sections,
    required super.totalQuestions,
    required super.totalMarks,
    super.useCount,
    super.lastUsedAt,
    required super.createdAt,
  });

  /// Create from database JSON
  factory TeacherPatternModel.fromJson(Map<String, dynamic> json) {
    // Parse sections from JSONB array or string
    List<PaperSectionEntity> parsedSections = [];

    if (json['sections'] != null) {
      try {
        if (json['sections'] is String) {
          // If sections is a string, parse it as JSON first
          final sectionsData = jsonDecode(json['sections'] as String) as List<dynamic>;
          parsedSections = sectionsData
              .map((section) => PaperSectionEntity.fromJson(section as Map<String, dynamic>))
              .toList();
        } else if (json['sections'] is List) {
          // If already a list, use it directly
          parsedSections = (json['sections'] as List<dynamic>)
              .map((section) => PaperSectionEntity.fromJson(section as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Silent fail - return empty sections on parse error
        parsedSections = [];
      }
    }

    return TeacherPatternModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      subjectId: json['subject_id'] as String,
      name: json['name'] as String,
      sections: parsedSections,
      totalQuestions: json['total_questions'] as int,
      totalMarks: json['total_marks'] as int,
      useCount: json['use_count'] as int? ?? 0,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to database JSON
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'name': name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'total_questions': totalQuestions,
      'total_marks': totalMarks,
      'use_count': useCount,
      'last_used_at': lastUsedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to entity
  TeacherPatternEntity toEntity() {
    return TeacherPatternEntity(
      id: id,
      tenantId: tenantId,
      teacherId: teacherId,
      subjectId: subjectId,
      name: name,
      sections: sections,
      totalQuestions: totalQuestions,
      totalMarks: totalMarks,
      useCount: useCount,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
    );
  }

  /// Create from entity
  factory TeacherPatternModel.fromEntity(TeacherPatternEntity entity) {
    return TeacherPatternModel(
      id: entity.id,
      tenantId: entity.tenantId,
      teacherId: entity.teacherId,
      subjectId: entity.subjectId,
      name: entity.name,
      sections: entity.sections,
      totalQuestions: entity.totalQuestions,
      totalMarks: entity.totalMarks,
      useCount: entity.useCount,
      lastUsedAt: entity.lastUsedAt,
      createdAt: entity.createdAt,
    );
  }
}
