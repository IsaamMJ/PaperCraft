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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory ExamCalendar.fromJson(Map<String, dynamic> json) {
    return ExamCalendar(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
      monthNumber: json['month_number'] as int,
      plannedStartDate: DateTime.parse(json['planned_start_date'] as String),
      plannedEndDate: DateTime.parse(json['planned_end_date'] as String),
      paperSubmissionDeadline: json['paper_submission_deadline'] != null
          ? DateTime.parse(json['paper_submission_deadline'] as String)
          : null,
      displayOrder: json['display_order'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
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
    isActive,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'ExamCalendar(examName: $examName, examType: $examType, monthNumber: $monthNumber)';
}
