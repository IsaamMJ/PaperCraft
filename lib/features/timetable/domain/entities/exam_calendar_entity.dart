import 'package:equatable/equatable.dart';
import 'dart:convert';
import 'mark_config_entity.dart';

/// Represents an exam calendar template that can be reused across academic years.
/// This is a master record for exam periods (e.g., "Mid-term Exams", "Final Exams").
///
/// Example:
/// ```dart
/// final calendar = ExamCalendarEntity(
///   id: 'uuid-123',
///   tenantId: 'tenant-456',
///   examName: 'Mid-term Exams',
///   examType: 'mid_term',
///   monthNumber: 11,
///   plannedStartDate: DateTime(2025, 11, 10),
///   plannedEndDate: DateTime(2025, 11, 30),
///   paperSubmissionDeadline: DateTime(2025, 11, 5),
/// );
/// ```
class ExamCalendarEntity extends Equatable {
  /// Unique identifier for the exam calendar
  final String id;

  /// Tenant ID to ensure multi-tenancy isolation
  final String tenantId;

  /// Name of the exam (e.g., "Mid-term Exams", "Final Exams")
  final String examName;

  /// Type of exam for categorization and filtering
  /// Valid values: 'mid_term', 'final', 'unit_test', 'monthly'
  final String examType;

  /// Month number (1-12) for quick filtering and organization
  final int monthNumber;

  /// Planned start date for this exam period
  final DateTime plannedStartDate;

  /// Planned end date for this exam period
  /// Must be >= plannedStartDate
  final DateTime plannedEndDate;

  /// Optional deadline for teachers to submit question papers
  final DateTime? paperSubmissionDeadline;

  /// Order for displaying calendars in UI
  /// Useful for sorting multiple calendars
  final int displayOrder;

  /// Additional metadata in JSON format
  /// Can store custom information like notes, version info, etc.
  final Map<String, dynamic>? metadata;

  /// Marks configuration for different grade ranges
  /// Maps grade ranges to their total marks (e.g., Grade 1-5: 25 marks)
  /// Can be null if marks haven't been configured yet
  final List<MarkConfigEntity>? marksConfig;

  /// Grades participating in this exam
  /// Example: [1, 2, 3, 4, 5] for grades 1-5
  /// This is selected during exam calendar creation by the admin
  /// Must be set before creating timetables
  final List<int>? selectedGradeNumbers;

  /// Whether this calendar is active
  /// Soft delete flag - inactive calendars are hidden from users
  final bool isActive;

  /// Timestamp when this calendar was created
  final DateTime createdAt;

  /// Timestamp when this calendar was last updated
  final DateTime updatedAt;

  const ExamCalendarEntity({
    required this.id,
    required this.tenantId,
    required this.examName,
    required this.examType,
    required this.monthNumber,
    required this.plannedStartDate,
    required this.plannedEndDate,
    this.paperSubmissionDeadline,
    this.displayOrder = 0,
    this.metadata,
    this.marksConfig,
    this.selectedGradeNumbers,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this entity with optional field overrides
  /// Useful for creating modified versions without mutation
  ExamCalendarEntity copyWith({
    String? id,
    String? tenantId,
    String? examName,
    String? examType,
    int? monthNumber,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    DateTime? paperSubmissionDeadline,
    int? displayOrder,
    Map<String, dynamic>? metadata,
    List<MarkConfigEntity>? marksConfig,
    List<int>? selectedGradeNumbers,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamCalendarEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      examName: examName ?? this.examName,
      examType: examType ?? this.examType,
      monthNumber: monthNumber ?? this.monthNumber,
      plannedStartDate: plannedStartDate ?? this.plannedStartDate,
      plannedEndDate: plannedEndDate ?? this.plannedEndDate,
      paperSubmissionDeadline:
          paperSubmissionDeadline ?? this.paperSubmissionDeadline,
      displayOrder: displayOrder ?? this.displayOrder,
      metadata: metadata ?? this.metadata,
      marksConfig: marksConfig ?? this.marksConfig,
      selectedGradeNumbers: selectedGradeNumbers ?? this.selectedGradeNumbers,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for API requests/storage
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
      'marks_config': marksConfig?.map((config) => config.toJson()).toList(),
      'selected_grade_numbers': selectedGradeNumbers,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (API responses/database)
  factory ExamCalendarEntity.fromJson(Map<String, dynamic> json) {
    final examName = json['exam_name'] as String;
    final rawExamType = json['exam_type'] as String;
    // Normalize exam type to handle corrupt database data
    final normalizedExamType = _normalizeExamType(rawExamType, examName);

    // Parse marks configuration if present
    // Supports three formats:
    // 1. Legacy list format: List<Map> with grade ranges
    // 2. New map format: Map with selected_grades and marks
    // 3. JSON string format: String representation of the above
    List<MarkConfigEntity>? marksConfigList;
    final marksConfigJson = json['marks_config'];
    if (marksConfigJson != null) {
      try {
        // Handle JSON string format (from database)
        if (marksConfigJson is String && marksConfigJson.isNotEmpty) {
          final parsed = jsonDecode(marksConfigJson);
          if (parsed is List) {
            marksConfigList = (parsed)
                .map((item) => MarkConfigEntity.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (parsed is Map<String, dynamic>) {
            marksConfigList = _convertMapConfigToList(parsed);
          }
        } else if (marksConfigJson is List) {
          // Legacy list format
          marksConfigList = (marksConfigJson)
              .map((item) => MarkConfigEntity.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (marksConfigJson is Map<String, dynamic>) {
          // New map format with selected_grades
          // Extract selected_grades for grade filtering in timetable creation
          // Convert to legacy format for backward compatibility
          final selectedGradesMap = marksConfigJson;
          marksConfigList = _convertMapConfigToList(selectedGradesMap);
        }
      } catch (e) {
      }
    }

    // Parse selected grade numbers from database (INTEGER[] -> List<int>)
    List<int>? selectedGrades;
    final selectedGradesJson = json['selected_grade_numbers'];
    if (selectedGradesJson != null) {
      if (selectedGradesJson is List) {
        selectedGrades = (selectedGradesJson).cast<int>().toList();
      }
    }

    return ExamCalendarEntity(
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
      marksConfig: marksConfigList,
      selectedGradeNumbers: selectedGrades,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Extract selected grades from marks_config
  /// Returns null if no grades are selected
  static List<int>? getSelectedGradesFromMarksConfig(List<MarkConfigEntity>? marksConfig) {
    if (marksConfig == null || marksConfig.isEmpty) {
      return null;
    }

    // Collect all grades covered by the marks config
    final selectedGrades = <int>{};
    for (final config in marksConfig) {
      for (int i = config.minGrade; i <= config.maxGrade; i++) {
        selectedGrades.add(i);
      }
    }

    final result = selectedGrades.toList()..sort();
    return result;
  }

  /// Convert new map format to legacy list format
  /// Map format: {"selected_grades": [1,2,3,4,5], "grades_1_to_5_marks": 25, ...}
  static List<MarkConfigEntity>? _convertMapConfigToList(Map<String, dynamic> configMap) {
    final selectedGrades = configMap['selected_grades'] as List<dynamic>?;
    if (selectedGrades == null || selectedGrades.isEmpty) {
      return null;
    }

    final grades = selectedGrades.cast<int>().toList()..sort();

    // Create mark configs for grade ranges
    List<MarkConfigEntity> configs = [];

    // Check for grades 1-5
    final grades1To5 = grades.where((g) => g <= 5).toList();
    if (grades1To5.isNotEmpty) {
      final marks1To5 = configMap['grades_1_to_5_marks'] as int?;
      if (marks1To5 != null) {
        configs.add(MarkConfigEntity(
          minGrade: grades1To5.first,
          maxGrade: grades1To5.last,
          totalMarks: marks1To5,
          label: 'Grades ${grades1To5.first}-${grades1To5.last}',
        ));
      }
    }

    // Check for grades 6-12
    final grades6To12 = grades.where((g) => g >= 6).toList();
    if (grades6To12.isNotEmpty) {
      final marks6To12 = configMap['grades_6_to_12_marks'] as int?;
      if (marks6To12 != null) {
        configs.add(MarkConfigEntity(
          minGrade: grades6To12.first,
          maxGrade: grades6To12.last,
          totalMarks: marks6To12,
          label: 'Grades ${grades6To12.first}-${grades6To12.last}',
        ));
      }
    }

    return configs.isEmpty ? null : configs;
  }

  @override
  String toString() {
    return 'ExamCalendarEntity('
        'id: $id, '
        'examName: $examName, '
        'examType: $examType, '
        'planned: $plannedStartDate - $plannedEndDate, '
        'isActive: $isActive)';
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        examName,
        examType,
        monthNumber,
        plannedStartDate,
        plannedEndDate,
        paperSubmissionDeadline,
        displayOrder,
        metadata,
        marksConfig,
        selectedGradeNumbers,
        isActive,
        createdAt,
        updatedAt,
      ];

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
