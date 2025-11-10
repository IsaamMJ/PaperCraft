import 'package:equatable/equatable.dart';

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
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (API responses/database)
  factory ExamCalendarEntity.fromJson(Map<String, dynamic> json) {
    return ExamCalendarEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
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
        isActive,
        createdAt,
        updatedAt,
      ];
}
