import 'package:papercraft/features/timetable/domain/entities/exam_calendar_entity.dart';

/// Data model for ExamCalendarEntity
/// Used for API requests/responses and database mapping
/// Extends the entity with no additional functionality (thin model pattern)
class ExamCalendarModel extends ExamCalendarEntity {
  const ExamCalendarModel({
    required super.id,
    required super.tenantId,
    required super.examName,
    required super.examType,
    required super.monthNumber,
    required super.plannedStartDate,
    required super.plannedEndDate,
    super.paperSubmissionDeadline,
    super.displayOrder,
    super.metadata,
    super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create model from entity
  factory ExamCalendarModel.fromEntity(ExamCalendarEntity entity) {
    return ExamCalendarModel(
      id: entity.id,
      tenantId: entity.tenantId,
      examName: entity.examName,
      examType: entity.examType,
      monthNumber: entity.monthNumber,
      plannedStartDate: entity.plannedStartDate,
      plannedEndDate: entity.plannedEndDate,
      paperSubmissionDeadline: entity.paperSubmissionDeadline,
      displayOrder: entity.displayOrder,
      metadata: entity.metadata,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create model from JSON (Supabase response)
  factory ExamCalendarModel.fromJson(Map<String, dynamic> json) {
    final examName = json['exam_name'] as String;
    final rawExamType = json['exam_type'] as String;
    // Normalize exam type to handle corrupt database data
    final normalizedExamType = _normalizeExamType(rawExamType, examName);

    return ExamCalendarModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examName: examName,
      examType: normalizedExamType,
      monthNumber: json['month_number'] as int,
      plannedStartDate:
          DateTime.parse(json['planned_start_date'] as String),
      plannedEndDate: DateTime.parse(json['planned_end_date'] as String),
      paperSubmissionDeadline: json['paper_submission_deadline'] != null
          ? DateTime.parse(json['paper_submission_deadline'] as String)
          : null,
      displayOrder: json['display_order'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String(),
      'planned_end_date': plannedEndDate.toIso8601String(),
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String(),
      'display_order': displayOrder,
      'metadata': metadata,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for API requests (excludes system fields)
  Map<String, dynamic> toJsonRequest() {
    return {
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String(),
      'planned_end_date': plannedEndDate.toIso8601String(),
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String(),
      'display_order': displayOrder,
      'metadata': metadata,
    };
  }

  /// Normalize exam type value - handles corrupt database data
  /// Valid database values: 'monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest'
  static String _normalizeExamType(String rawValue, String examName) {
    final normalized = rawValue.toLowerCase().trim();
    final validTypes = ['monthlytest', 'halfyearlytest', 'quarterlytest', 'finalexam', 'dailytest'];

    // If already valid (camelCase check), return as-is
    if (validTypes.contains(normalized)) {
      return rawValue; // Return original casing
    }

    // Map common variations to database enum values
    final typeMapping = {
      'monthly': 'monthlyTest',
      'monthly test': 'monthlyTest',
      'monthlytests': 'monthlyTest',
      'monthlytest': 'monthlyTest',
      'monthly exam': 'monthlyTest',
      'mid_term': 'halfYearlyTest',
      'mid term': 'halfYearlyTest',
      'midterm': 'halfYearlyTest',
      'mid-term': 'halfYearlyTest',
      'midyear': 'halfYearlyTest',
      'halfyearly': 'halfYearlyTest',
      'half yearly': 'halfYearlyTest',
      'half-yearly': 'halfYearlyTest',
      'quarterly': 'quarterlyTest',
      'quarterly test': 'quarterlyTest',
      'final': 'finalExam',
      'final exam': 'finalExam',
      'finalexam': 'finalExam',
      'finalsemester': 'finalExam',
      'unit': 'dailyTest',
      'unit test': 'dailyTest',
      'unittests': 'dailyTest',
      'unittest': 'dailyTest',
      'daily test': 'dailyTest',
      'november': 'monthlyTest',
      'december': 'monthlyTest',
      'october': 'monthlyTest',
      'september': 'monthlyTest',
    };

    // First try direct mapping
    if (typeMapping.containsKey(normalized)) {
      return typeMapping[normalized]!;
    }

    // If not found in mapping, try to extract from exam name
    final examNameLower = examName.toLowerCase();

    if (examNameLower.contains('monthly')) {
      return 'monthlyTest';
    }
    if (examNameLower.contains('mid term') || examNameLower.contains('midterm') || examNameLower.contains('mid-term') || examNameLower.contains('half yearly')) {
      return 'halfYearlyTest';
    }
    if (examNameLower.contains('quarterly') || examNameLower.contains('quarter')) {
      return 'quarterlyTest';
    }
    if (examNameLower.contains('final')) {
      return 'finalExam';
    }
    if (examNameLower.contains('unit test') || examNameLower.contains('unit-test') || examNameLower.contains('unittest') || examNameLower.contains('daily')) {
      return 'dailyTest';
    }

    // Default to 'monthlyTest' if cannot determine
    return 'monthlyTest';
  }
}
