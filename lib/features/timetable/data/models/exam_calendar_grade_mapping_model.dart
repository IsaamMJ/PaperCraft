import 'package:papercraft/features/timetable/domain/entities/exam_calendar_grade_mapping_entity.dart';

/// Model for exam calendar grade mapping - used for JSON serialization
class ExamCalendarGradeMappingModel extends ExamCalendarGradeMappingEntity {
  const ExamCalendarGradeMappingModel({
    required String id,
    required String tenantId,
    required String examCalendarId,
    required String gradeSectionId,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
    id: id,
    tenantId: tenantId,
    examCalendarId: examCalendarId,
    gradeSectionId: gradeSectionId,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Create from JSON (from Supabase)
  factory ExamCalendarGradeMappingModel.fromJson(Map<String, dynamic> json) {
    return ExamCalendarGradeMappingModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examCalendarId: json['exam_calendar_id'] as String,
      gradeSectionId: json['grade_section_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON (for Supabase insert/update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'exam_calendar_id': examCalendarId,
      'grade_section_id': gradeSectionId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to insert payload (excludes id, timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'tenant_id': tenantId,
      'exam_calendar_id': examCalendarId,
      'grade_section_id': gradeSectionId,
      'is_active': isActive,
    };
  }
}
