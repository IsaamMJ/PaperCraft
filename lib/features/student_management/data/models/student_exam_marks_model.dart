import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';

/// Data model for StudentExamMarksEntity
/// Handles JSON serialization/deserialization and conversion to/from entities
class StudentExamMarksModel extends StudentExamMarksEntity {
  const StudentExamMarksModel({
    required super.id,
    required super.tenantId,
    required super.studentId,
    required super.examTimetableEntryId,
    required super.totalMarks,
    required super.status,
    super.remarks,
    required super.enteredBy,
    required super.isDraft,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create a StudentExamMarksModel from a StudentExamMarksEntity
  factory StudentExamMarksModel.fromEntity(StudentExamMarksEntity entity) {
    return StudentExamMarksModel(
      id: entity.id,
      tenantId: entity.tenantId,
      studentId: entity.studentId,
      examTimetableEntryId: entity.examTimetableEntryId,
      totalMarks: entity.totalMarks,
      status: entity.status,
      remarks: entity.remarks,
      enteredBy: entity.enteredBy,
      isDraft: entity.isDraft,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create a StudentExamMarksModel from JSON (from API/database)
  factory StudentExamMarksModel.fromJson(Map<String, dynamic> json) {
    return StudentExamMarksModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      studentId: json['student_id'] as String,
      examTimetableEntryId: json['exam_timetable_entry_id'] as String,
      totalMarks: (json['total_marks'] as num).toDouble(),
      status: StudentMarkStatusString.fromString(json['status'] as String),
      remarks: json['remarks'] as String?,
      enteredBy: json['entered_by'] as String,
      isDraft: json['is_draft'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert StudentExamMarksModel to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'student_id': studentId,
      'exam_timetable_entry_id': examTimetableEntryId,
      'total_marks': totalMarks,
      'status': status.toString(),
      'remarks': remarks,
      'entered_by': enteredBy,
      'is_draft': isDraft,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON request format (for creating/updating marks)
  Map<String, dynamic> toJsonRequest() {
    return {
      'student_id': studentId,
      'exam_timetable_entry_id': examTimetableEntryId,
      'total_marks': totalMarks,
      'status': status.toString(),
      'remarks': remarks,
      'is_draft': isDraft,
    };
  }

  /// Create a copy with modified fields
  StudentExamMarksModel copyWith({
    String? id,
    String? tenantId,
    String? studentId,
    String? examTimetableEntryId,
    double? totalMarks,
    StudentMarkStatus? status,
    String? remarks,
    String? enteredBy,
    bool? isDraft,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentExamMarksModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      studentId: studentId ?? this.studentId,
      examTimetableEntryId: examTimetableEntryId ?? this.examTimetableEntryId,
      totalMarks: totalMarks ?? this.totalMarks,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      enteredBy: enteredBy ?? this.enteredBy,
      isDraft: isDraft ?? this.isDraft,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
