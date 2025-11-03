import 'package:equatable/equatable.dart';

/// Status of an exam timetable
enum TimetableStatus {
  draft,      // Being edited
  published,  // Published, papers created
  completed,  // Exam finished
  cancelled,  // Cancelled before publishing
}

/// Extension to convert enum to string and vice versa
extension TimetableStatusX on TimetableStatus {
  String toShortString() => toString().split('.').last;

  static TimetableStatus fromString(String value) {
    return TimetableStatus.values.firstWhere(
      (e) => e.toShortString() == value,
      orElse: () => TimetableStatus.draft,
    );
  }
}

/// Represents an actual exam timetable created by admin
///
/// Can be created FROM exam_calendar (planned exams) or AD-HOC (daily tests)
/// When published, automatically creates DRAFT papers for all assigned teachers
class ExamTimetable extends Equatable {
  final String id;
  final String tenantId;
  final String createdBy;
  final String? examCalendarId; // Null for ad-hoc timetables
  final String examName;
  final String examType; // monthlyTest, quarterlyTest, halfYearlyTest, finalExam, dailyTest
  final int? examNumber; // For daily tests: week 1, week 2, etc.
  final String academicYear;
  final TimetableStatus status;
  final DateTime? publishedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamTimetable({
    required this.id,
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    required this.examName,
    required this.examType,
    this.examNumber,
    required this.academicYear,
    required this.status,
    this.publishedAt,
    required this.isActive,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Is this timetable in draft status?
  bool get isDraft => status == TimetableStatus.draft;

  /// Is this timetable published?
  bool get isPublished => status == TimetableStatus.published;

  /// Can this timetable be edited?
  bool get canEdit => status == TimetableStatus.draft;

  /// Display name for UI (handles both from-calendar and ad-hoc)
  String get displayName => examNumber != null ? '$examName - Week $examNumber' : examName;

  /// Is this from exam calendar or ad-hoc?
  bool get isFromCalendar => examCalendarId != null;
  bool get isAdHoc => examCalendarId == null;

  /// Create a copy of this object with modified fields
  ExamTimetable copyWith({
    String? id,
    String? tenantId,
    String? createdBy,
    String? examCalendarId,
    String? examName,
    String? examType,
    int? examNumber,
    String? academicYear,
    TimetableStatus? status,
    DateTime? publishedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetable(
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

  /// Convert to JSON for API requests
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
      'status': status.toShortString(),
      'published_at': publishedAt?.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory ExamTimetable.fromJson(Map<String, dynamic> json) {
    return ExamTimetable(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      createdBy: json['created_by'] as String,
      examCalendarId: json['exam_calendar_id'] as String?,
      examName: json['exam_name'] as String,
      examType: json['exam_type'] as String,
      examNumber: json['exam_number'] as int?,
      academicYear: json['academic_year'] as String,
      status: TimetableStatusX.fromString(json['status'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
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

  @override
  String toString() =>
      'ExamTimetable(examName: $examName, status: ${status.toShortString()}, displayName: $displayName)';
}
