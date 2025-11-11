import 'package:equatable/equatable.dart';

/// Represents a single exam entry in an exam timetable
///
/// Each entry specifies:
/// - Which grade section takes the exam (references grade_sections table)
/// - What subject is being examined
/// - When (date, time, duration)
/// - Time stored as Duration for compatibility with backend
class ExamTimetableEntryEntity extends Equatable {
  final String? id; // null for new entries, set by backend
  final String tenantId;
  final String timetableId;
  final String gradeSectionId; // References grade_sections table (includes both grade_id and section_name) - REQUIRED
  final String? gradeId; // Denormalized for convenience (can be derived from grade_sections join)
  final int? gradeNumber; // Fetched from grades table for display
  final String? section; // Fetched from grade_sections for display ('A', 'B', 'C', etc.)
  final String subjectId;
  final String? subjectName; // Fetched from subject_catalog for display
  final DateTime examDate;
  final Duration startTime; // Time as Duration (e.g., Duration(hours: 9, minutes: 0))
  final Duration endTime; // Calculated from startTime + durationMinutes
  final int durationMinutes; // 120 = 2 hours
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamTimetableEntryEntity({
    this.id,
    required this.tenantId,
    required this.timetableId,
    required this.gradeSectionId, // Required - must be a valid UUID from grade_sections table
    this.gradeId,
    this.gradeNumber,
    this.section,
    required this.subjectId,
    this.subjectName,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        timetableId,
        gradeSectionId,
        gradeId,
        gradeNumber,
        section,
        subjectId,
        subjectName,
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
      'ExamTimetableEntryEntity(grade: $gradeId-$section, date: ${examDate.toString().split(' ')[0]}, time: $startTimeDisplay)';

  /// Get start time formatted as "HH:MM AM/PM"
  String get startTimeDisplay {
    final hours = startTime.inHours;
    final minutes = startTime.inMinutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Get end time formatted as "HH:MM AM/PM"
  String get endTimeDisplay {
    final hours = endTime.inHours;
    final minutes = endTime.inMinutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }

  /// Get schedule display string (e.g., "09:00 AM - 11:00 AM")
  String get scheduleDisplay => '$startTimeDisplay - $endTimeDisplay';

  /// Get exam date formatted as "MMM DD, YYYY" (e.g., "Nov 15, 2025")
  String get examDateDisplay {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthNames[examDate.month - 1];
    return '$month ${examDate.day}, ${examDate.year}';
  }

  /// Check if time range is valid (endTime > startTime)
  bool get hasValidTimeRange => endTime > startTime;

  /// Create a copy with modified fields
  ExamTimetableEntryEntity copyWith({
    String? id,
    String? tenantId,
    String? timetableId,
    String? gradeSectionId,
    String? gradeId,
    int? gradeNumber,
    String? section,
    String? subjectId,
    String? subjectName,
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
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      gradeId: gradeId ?? this.gradeId,
      gradeNumber: gradeNumber ?? this.gradeNumber,
      section: section ?? this.section,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Wrapper class for exam entries with metadata
class ExamEntriesData extends Equatable {
  final List<ExamTimetableEntryEntity> entries;
  final int totalCount;
  final DateTime? lastUpdated;

  const ExamEntriesData({
    required this.entries,
    this.totalCount = 0,
    this.lastUpdated,
  });

  @override
  List<Object?> get props => [entries, totalCount, lastUpdated];

  /// Get entries grouped by grade-section
  Map<String, List<ExamTimetableEntryEntity>> groupByGradeSection() {
    final grouped = <String, List<ExamTimetableEntryEntity>>{};
    for (var entry in entries) {
      final key = '${entry.gradeId}-${entry.section}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  /// Get entries sorted by date and time
  List<ExamTimetableEntryEntity> getSorted() {
    final sorted = List<ExamTimetableEntryEntity>.from(entries);
    sorted.sort((a, b) {
      final dateCompare = a.examDate.compareTo(b.examDate);
      if (dateCompare != 0) return dateCompare;
      // If same date, sort by time
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }

  /// Check for date-time conflicts
  List<String> getConflicts() {
    final conflicts = <String>[];
    for (int i = 0; i < entries.length; i++) {
      for (int j = i + 1; j < entries.length; j++) {
        final entry1 = entries[i];
        final entry2 = entries[j];

        // Check if same grade-section
        if (entry1.gradeId == entry2.gradeId &&
            entry1.section == entry2.section) {
          // Check if overlapping times on same date
          if (entry1.examDate == entry2.examDate) {
            // Check if times overlap
            if (entry1.startTime == entry2.startTime) {
              conflicts.add(
                'Conflict: Grade ${entry1.gradeId}-${entry1.section} has ${entry1.subjectId} and ${entry2.subjectId} at same time',
              );
            }
          }
        }
      }
    }
    return conflicts;
  }
}
