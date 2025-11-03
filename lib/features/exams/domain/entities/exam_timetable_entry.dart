import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Individual entry in a timetable (one per grade/subject/section combination)
///
/// Defines WHEN each grade/subject/section has their exam
/// Examples:
/// - Grade 5-A, Maths, 2024-06-15, 09:00-10:30
/// - Grade 5-A, English, 2024-06-16, 09:00-10:00
/// - Grade 6-B, Science, 2024-06-20, 10:00-11:30
class ExamTimetableEntry extends Equatable {
  final String id;
  final String tenantId;
  final String timetableId;
  final String gradeId;
  final String subjectId;
  final String section;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int durationMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamTimetableEntry({
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
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// User-friendly display: "Grade 5-A Maths"
  String get displayName => '$gradeId-$section $subjectId';

  /// Format time range: "09:00 - 10:30"
  String get timeRange =>
      '${_formatTime(startTime)} - ${_formatTime(endTime)}';

  /// Format exam date: "Jun 15, 2024"
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[examDate.month - 1]} ${examDate.day}, ${examDate.year}';
  }

  /// Helper to format TimeOfDay
  static String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Parse TimeOfDay from "HH:mm" format
  static TimeOfDay parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  /// Create a copy of this object with modified fields
  ExamTimetableEntry copyWith({
    String? id,
    String? tenantId,
    String? timetableId,
    String? gradeId,
    String? subjectId,
    String? section,
    DateTime? examDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? durationMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetableEntry(
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

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'timetable_id': timetableId,
      'grade_id': gradeId,
      'subject_id': subjectId,
      'section': section,
      'exam_date': examDate.toIso8601String().split('T')[0], // Date only
      'start_time': timeRange.split(' - ')[0], // "HH:mm"
      'end_time': timeRange.split(' - ')[1], // "HH:mm"
      'duration_minutes': durationMinutes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON response from API
  factory ExamTimetableEntry.fromJson(Map<String, dynamic> json) {
    return ExamTimetableEntry(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      timetableId: json['timetable_id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      section: json['section'] as String,
      examDate: DateTime.parse(json['exam_date'] as String),
      startTime: parseTime(json['start_time'] as String),
      endTime: parseTime(json['end_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
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

  @override
  String toString() =>
      'ExamTimetableEntry(displayName: $displayName, examDate: $formattedDate, timeRange: $timeRange)';
}
