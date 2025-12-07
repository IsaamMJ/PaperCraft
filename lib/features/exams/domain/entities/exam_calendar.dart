import 'package:equatable/equatable.dart';

/// Represents a planned exam in the school's calendar (yearly planning)
///
/// Examples:
/// - June Monthly Test (monthlyTest)
/// - September Quarterly Test (quarterlyTest)
/// - December Half-Yearly (halfYearlyTest)
/// - May Final Exam (finalExam)
///
/// NOT for daily tests (those are created ad-hoc in timetables)
class ExamCalendar extends Equatable {
  final String id;
  final String tenantId;
  final String examName;
  final String examType; // monthlyTest, quarterlyTest, halfYearlyTest, finalExam
  final int monthNumber; // 1-12 (when this exam typically occurs)
  final DateTime plannedStartDate;
  final DateTime plannedEndDate;
  final DateTime? paperSubmissionDeadline; // Soft deadline for paper creation
  final int displayOrder; // For UI ordering
  final Map<String, dynamic>? metadata; // Future expansion
  final Map<String, dynamic>? marksConfig; // Grade-wise mark configurations
  final List<int>? selectedGradeNumbers; // Grades participating in this exam (e.g., [1, 2, 3, 4, 5])
  final int? coreMaxMarks; // Max marks for core subjects
  final int? auxiliaryMaxMarks; // Max marks for auxiliary subjects
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamCalendar({
    required this.id,
    required this.tenantId,
    required this.examName,
    required this.examType,
    required this.monthNumber,
    required this.plannedStartDate,
    required this.plannedEndDate,
    this.paperSubmissionDeadline,
    required this.displayOrder,
    this.metadata,
    this.marksConfig,
    this.selectedGradeNumbers,
    this.coreMaxMarks,
    this.auxiliaryMaxMarks,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Is this exam in the future?
  bool get isUpcoming => DateTime.now().isBefore(plannedStartDate);

  /// Has the paper submission deadline passed?
  bool get isPastDeadline =>
      paperSubmissionDeadline != null &&
      DateTime.now().isAfter(paperSubmissionDeadline!);

  /// Days remaining until deadline (null if no deadline)
  int? get daysUntilDeadline {
    if (paperSubmissionDeadline == null) return null;
    return paperSubmissionDeadline!.difference(DateTime.now()).inDays;
  }

  /// Create a copy of this object with modified fields
  ExamCalendar copyWith({
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
    Map<String, dynamic>? marksConfig,
    List<int>? selectedGradeNumbers,
    int? coreMaxMarks,
    int? auxiliaryMaxMarks,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamCalendar(
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
      coreMaxMarks: coreMaxMarks ?? this.coreMaxMarks,
      auxiliaryMaxMarks: auxiliaryMaxMarks ?? this.auxiliaryMaxMarks,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'exam_name': examName,
      'exam_type': examType,
      'month_number': monthNumber,
      'planned_start_date': plannedStartDate.toIso8601String().split('T')[0], // Date only
      'planned_end_date': plannedEndDate.toIso8601String().split('T')[0], // Date only
      'paper_submission_deadline': paperSubmissionDeadline?.toIso8601String().split('T')[0],
      'display_order': displayOrder,
      'metadata': metadata,
      'marks_config': marksConfig,
      'selected_grade_numbers': selectedGradeNumbers,
      'core_max_marks': coreMaxMarks,
      'auxiliary_max_marks': auxiliaryMaxMarks,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory ExamCalendar.fromJson(Map<String, dynamic> json) {
    // Normalize exam_type in case database has corrupt data
    String normalizedExamType = _normalizeExamTypeValue(
      json['exam_type'] as String,
      json['exam_name'] as String,
    );

    // Parse selected grade numbers from database (INTEGER[] -> List<int>)
    List<int>? selectedGrades;
    final selectedGradesJson = json['selected_grade_numbers'];
    if (selectedGradesJson != null) {
      if (selectedGradesJson is List) {
        selectedGrades = (selectedGradesJson).cast<int>().toList();
      }
    }

    return ExamCalendar(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examName: json['exam_name'] as String,
      examType: normalizedExamType,
      monthNumber: json['month_number'] as int,
      plannedStartDate: DateTime.parse(json['planned_start_date'] as String),
      plannedEndDate: DateTime.parse(json['planned_end_date'] as String),
      paperSubmissionDeadline: json['paper_submission_deadline'] != null
          ? DateTime.parse(json['paper_submission_deadline'] as String)
          : null,
      displayOrder: json['display_order'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
      marksConfig: json['marks_config'] as Map<String, dynamic>?,
      selectedGradeNumbers: selectedGrades,
      coreMaxMarks: json['core_max_marks'] as int?,
      auxiliaryMaxMarks: json['auxiliary_max_marks'] as int?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Normalize exam type value - handles corrupt database data
  /// Valid values: 'mid_term', 'final', 'unit_test', 'monthly'
  static String _normalizeExamTypeValue(String rawValue, String examName) {
    final normalized = rawValue.toLowerCase().trim();
    final validTypes = ['mid_term', 'final', 'unit_test', 'monthly'];

    // If already valid, return as-is
    if (validTypes.contains(normalized)) {
      return normalized;
    }

    // Map common variations to valid types
    final typeMapping = {
      'midterm': 'mid_term',
      'mid-term': 'mid_term',
      'mid term': 'mid_term',
      'midyear': 'mid_term',
      'mid year': 'mid_term',
      'halfyearly': 'mid_term',
      'half yearly': 'mid_term',
      'half-yearly': 'mid_term',
      'finalsemester': 'final',
      'final semester': 'final',
      'final exam': 'final',
      'finalexam': 'final',
      'unittests': 'unit_test',
      'unit tests': 'unit_test',
      'unit-test': 'unit_test',
      'unitest': 'unit_test',
      'monthlytests': 'monthly',
      'monthly tests': 'monthly',
      'monthly test': 'monthly',
      'monthlyexam': 'monthly',
      'monthly exam': 'monthly',
    };

    // First try direct mapping
    if (typeMapping.containsKey(normalized)) {
      return typeMapping[normalized]!;
    }

    // If not found in mapping, try to extract from exam name
    final examNameLower = examName.toLowerCase();

    if (examNameLower.contains('monthly')) {
      return 'monthly';
    }
    if (examNameLower.contains('mid term') || examNameLower.contains('midterm') || examNameLower.contains('mid-term')) {
      return 'mid_term';
    }
    if (examNameLower.contains('final')) {
      return 'final';
    }
    if (examNameLower.contains('unit test') || examNameLower.contains('unit-test') || examNameLower.contains('unittest')) {
      return 'unit_test';
    }

    // Default to 'monthly' if cannot determine
    return 'monthly';
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
    coreMaxMarks,
    auxiliaryMaxMarks,
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'ExamCalendar(examName: $examName, examType: $examType, monthNumber: $monthNumber)';
}
