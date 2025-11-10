import 'package:equatable/equatable.dart';

/// Represents an individual exam entry in a timetable.
/// This is a specific grade+subject exam scheduled for a particular date and time.
///
/// Example:
/// ```dart
/// final entry = ExamTimetableEntryEntity(
///   id: 'uuid-123',
///   tenantId: 'tenant-456',
///   timetableId: 'timetable-789',
///   gradeId: 'grade-10',
///   subjectId: 'subject-english',
///   section: 'A',
///   examDate: DateTime(2025, 11, 15),
///   startTime: TimeOfDay(9, 0),
///   endTime: TimeOfDay(11, 0),
///   durationMinutes: 120,
/// );
/// ```
class ExamTimetableEntryEntity extends Equatable {
  /// Unique identifier for this exam entry
  final String id;

  /// Tenant ID for multi-tenancy isolation
  final String tenantId;

  /// ID of the timetable this entry belongs to
  /// Foreign key to exam_timetables
  final String timetableId;

  /// ID of the grade for this exam
  /// Foreign key to grades table
  final String gradeId;

  /// ID of the subject for this exam
  /// Foreign key to subjects table
  final String subjectId;

  /// Section (A, B, C, etc.) within the grade
  /// Enables separate exams for different sections
  final String section;

  /// Date when this exam is scheduled
  final DateTime examDate;

  /// Start time of the exam (stored as TimeOfDay equivalent)
  /// Represented as Duration from midnight
  final Duration startTime;

  /// End time of the exam (stored as TimeOfDay equivalent)
  /// Represented as Duration from midnight
  /// Must be > startTime
  final Duration endTime;

  /// Duration of the exam in minutes
  /// Should equal endTime - startTime (in minutes)
  /// Used for validation and display
  final int durationMinutes;

  /// Whether this entry is active
  /// Soft delete flag - inactive entries are hidden
  final bool isActive;

  /// Timestamp when this entry was created
  final DateTime createdAt;

  /// Timestamp when this entry was last updated
  final DateTime updatedAt;

  const ExamTimetableEntryEntity({
    required this.id,
    required this.tenantId,
    required this.timetableId,
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if exam times are valid
  /// startTime must be < endTime
  bool get hasValidTimeRange => startTime < endTime;

  /// Get start time as hour:minute string for display
  String get startTimeDisplay {
    final hours = startTime.inHours;
    final minutes = startTime.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Get end time as hour:minute string for display
  String get endTimeDisplay {
    final hours = endTime.inHours;
    final minutes = endTime.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Get formatted date string (e.g., "Nov 15, 2025")
  String get examDateDisplay {
    return '${_monthName(examDate.month)} ${examDate.day}, ${examDate.year}';
  }

  /// Get full exam schedule string
  /// e.g., "Nov 15, 2025 - 09:00 to 11:00 (120 min)"
  String get scheduleDisplay {
    return '$examDateDisplay - $startTimeDisplay to $endTimeDisplay ($durationMinutes min)';
  }

  /// Create a copy with optional field overrides
  ExamTimetableEntryEntity copyWith({
    String? id,
    String? tenantId,
    String? timetableId,
    String? gradeId,
    String? subjectId,
    String? section,
    DateTime? examDate,
    Duration? startTime,
    Duration? endTime,
    int? durationMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetableEntryEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      timetableId: timetableId ?? this.timetableId,
      gradeId: gradeId ?? this.gradeId,
      subjectId: subjectId ?? this.subjectId,
      section: section ?? this.section,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Soft delete this entry
  ExamTimetableEntryEntity softDelete() {
    return copyWith(isActive: false);
  }

  /// Reactivate a soft-deleted entry
  ExamTimetableEntryEntity reactivate() {
    return copyWith(isActive: true);
  }

  /// Helper to get month name from month number
  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Convert to JSON for API requests/storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'timetable_id': timetableId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'exam_date': examDate.toIso8601String(),
      'start_time': _durationToTimeString(startTime),
      'end_time': _durationToTimeString(endTime),
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (API responses/database)
  factory ExamTimetableEntryEntity.fromJson(Map<String, dynamic> json) {
    return ExamTimetableEntryEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      timetableId: json['timetable_id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      section: json['section'] as String,
      examDate: DateTime.parse(json['exam_date'] as String),
      startTime: _timeStringToDuration(json['start_time'] as String),
      endTime: _timeStringToDuration(json['end_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert Duration to HH:MM format string
  static String _durationToTimeString(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:00';
  }

  /// Convert HH:MM:SS format string to Duration
  static Duration _timeStringToDuration(String timeStr) {
    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }

  @override
  String toString() {
    return 'ExamTimetableEntryEntity('
        'id: $id, '
        'gradeId: $gradeId, '
        'subjectId: $subjectId, '
        'section: $section, '
        'examDate: ${examDate.toIso8601String()}, '
        'time: $startTimeDisplay-$endTimeDisplay, '
        'isActive: $isActive)';
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        timetableId,
        gradeId,
        subjectId,
        section,
        examDate,
        startTime,
        endTime,
        durationMinutes,
        isActive,
        createdAt,
        updatedAt,
      ];
}
