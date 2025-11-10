import 'package:equatable/equatable.dart';

/// Represents a specific exam timetable instance for an academic year.
/// This is created from a calendar template and contains the actual exam schedule.
///
/// Status flow: draft → published → archived
///
/// Example:
/// ```dart
/// final timetable = ExamTimetableEntity(
///   id: 'uuid-123',
///   tenantId: 'tenant-456',
///   createdBy: 'admin-789',
///   examName: 'Mid-term Exams',
///   examType: 'mid_term',
///   academicYear: '2025-2026',
///   status: 'draft',
/// );
/// ```
class ExamTimetableEntity extends Equatable {
  /// Unique identifier for the timetable
  final String id;

  /// Tenant ID for multi-tenancy isolation
  final String tenantId;

  /// ID of the admin who created this timetable
  /// Used to track ownership and audit trail
  final String createdBy;

  /// Optional reference to the exam calendar template
  /// Can be null if timetable is created standalone
  final String? examCalendarId;

  /// Name of the exam (can be same or different from calendar)
  final String examName;

  /// Type of exam for categorization
  /// Valid values: 'mid_term', 'final', 'unit_test', 'monthly'
  final String examType;

  /// Exam number for this year (1st, 2nd, 3rd attempt, etc.)
  /// Useful if multiple exams of same type occur
  final int? examNumber;

  /// Academic year this timetable is for
  /// Format: "2025-2026" or "2025-27"
  final String academicYear;

  /// Current status of the timetable
  /// Valid values: 'draft', 'published', 'archived'
  /// - draft: Still being built, entries can be added/modified
  /// - published: Finalized and visible to teachers
  /// - archived: Old timetable, kept for records
  final String status;

  /// Timestamp when timetable was published
  /// Null until status changes to 'published'
  final DateTime? publishedAt;

  /// Whether this timetable is active
  /// Soft delete flag - inactive timetables are hidden
  final bool isActive;

  /// Additional metadata in JSON format
  /// Can store custom info, notes, version tracking, etc.
  final Map<String, dynamic>? metadata;

  /// Timestamp when created
  final DateTime createdAt;

  /// Timestamp when last updated
  final DateTime updatedAt;

  const ExamTimetableEntity({
    required this.id,
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    required this.examName,
    required this.examType,
    this.examNumber,
    required this.academicYear,
    this.status = 'draft',
    this.publishedAt,
    this.isActive = true,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if timetable is in draft status
  /// Draft timetables can still be modified
  bool get isDraft => status == 'draft';

  /// Check if timetable is published
  /// Published timetables are finalized
  bool get isPublished => status == 'published';

  /// Check if timetable is archived
  /// Archived timetables are read-only
  bool get isArchived => status == 'archived';

  /// Check if this timetable can be edited
  /// Only draft timetables can be edited
  bool get canEdit => isDraft && isActive;

  /// Check if this timetable can be published
  /// Only draft timetables can be published
  bool get canPublish => isDraft && isActive;

  /// Create a copy with optional field overrides
  /// Maintains immutability while allowing modifications
  ExamTimetableEntity copyWith({
    String? id,
    String? tenantId,
    String? createdBy,
    String? examCalendarId,
    String? examName,
    String? examType,
    int? examNumber,
    String? academicYear,
    String? status,
    DateTime? publishedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetableEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      examCalendarId: examCalendarId ?? this.examCalendarId,
      examName: examName ?? this.examName,
      examType: examType ?? this.examType,
      examNumber: examNumber ?? this.examNumber,
      academicYear: academicYear ?? this.academicYear,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Mark as published with current timestamp
  ExamTimetableEntity markAsPublished() {
    return copyWith(
      status: 'published',
      publishedAt: DateTime.now(),
    );
  }

  /// Mark as archived
  ExamTimetableEntity markAsArchived() {
    return copyWith(
      status: 'archived',
    );
  }

  /// Soft delete (mark as inactive)
  ExamTimetableEntity softDelete() {
    return copyWith(isActive: false);
  }

  /// Reactivate a soft-deleted timetable
  ExamTimetableEntity reactivate() {
    return copyWith(isActive: true);
  }

  /// Convert to JSON for API requests/storage
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

  /// Create from JSON (API responses/database)
  factory ExamTimetableEntity.fromJson(Map<String, dynamic> json) {
    return ExamTimetableEntity(
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

  @override
  String toString() {
    return 'ExamTimetableEntity('
        'id: $id, '
        'examName: $examName, '
        'academicYear: $academicYear, '
        'status: $status, '
        'isActive: $isActive)';
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        createdBy,
        examCalendarId,
        examName,
        examType,
        examNumber,
        academicYear,
        status,
        publishedAt,
        isActive,
        metadata,
        createdAt,
        updatedAt,
      ];
}
