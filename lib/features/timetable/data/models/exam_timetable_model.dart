import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entity.dart';

/// Data model for ExamTimetableEntity
class ExamTimetableModel extends ExamTimetableEntity {
  const ExamTimetableModel({
    required super.id,
    required super.tenantId,
    required super.createdBy,
    super.examCalendarId,
    required super.examName,
    required super.examType,
    super.examNumber,
    required super.academicYear,
    super.status,
    super.publishedAt,
    super.isActive,
    super.metadata,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ExamTimetableModel.fromEntity(ExamTimetableEntity entity) {
    return ExamTimetableModel(
      id: entity.id,
      tenantId: entity.tenantId,
      createdBy: entity.createdBy,
      examCalendarId: entity.examCalendarId,
      examName: entity.examName,
      examType: entity.examType,
      examNumber: entity.examNumber,
      academicYear: entity.academicYear,
      status: entity.status,
      publishedAt: entity.publishedAt,
      isActive: entity.isActive,
      metadata: entity.metadata,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory ExamTimetableModel.fromJson(Map<String, dynamic> json) {
    return ExamTimetableModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String,
      examCalendarId: json['exam_calendar_id'] as String?,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
      examNumber: json['exam_number'] as int?,
      academicYear: json['academic_year'] as String,
      status: json['status'] as String? ?? 'draft',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'created_by': createdBy,
      'exam_calendar_id': examCalendarId,
      'exam_name': examName,
      'exam_type': examType,
      'exam_number': examNumber,
      'academic_year': academicYear,
      'status': status,
      'published_at': publishedAt?.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonRequest() {
    return {
      'exam_name': examName,
      'exam_type': examType,
      'exam_number': examNumber,
      'academic_year': academicYear,
      'exam_calendar_id': examCalendarId,
      'metadata': metadata,
    };
  }
}
