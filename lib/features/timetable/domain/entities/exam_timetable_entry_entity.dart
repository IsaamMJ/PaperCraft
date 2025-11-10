import 'package:equatable/equatable.dart';

/// Represents a single exam entry in an exam timetable
///
/// Each entry specifies:
/// - Which grade and section takes the exam
/// - What subject is being examined
/// - When (date, time, duration)
/// - Where (location/room)
class ExamTimetableEntryEntity extends Equatable {
  final String? id; // null for new entries, set by backend
  final String timetableId;
  final String gradeId;
  final String section; // 'A', 'B', 'C', etc.
  final String subjectId;
  final String subjectName; // For display
  final DateTime examDate;
  final String startTime; // Format: "09:00 AM"
  final int durationMinutes; // 120 = 2 hours
  final String? location; // Hall 1, Room 101, etc.
  final String? notes; // Special instructions
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ExamTimetableEntryEntity({
    this.id,
    required this.timetableId,
    required this.gradeId,
    required this.section,
    required this.subjectId,
    required this.subjectName,
    required this.examDate,
    required this.startTime,
    required this.durationMinutes,
    this.location,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        timetableId,
        gradeId,
        section,
        subjectId,
        subjectName,
        examDate,
        startTime,
        durationMinutes,
        location,
        notes,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() =>
      'ExamTimetableEntryEntity(grade: $gradeId-$section, subject: $subjectName, date: ${examDate.toString().split(' ')[0]}, time: $startTime)';

  /// Create a copy with modified fields
  ExamTimetableEntryEntity copyWith({
    String? id,
    String? timetableId,
    String? gradeId,
    String? section,
    String? subjectId,
    String? subjectName,
    DateTime? examDate,
    String? startTime,
    int? durationMinutes,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamTimetableEntryEntity(
      id: id ?? this.id,
      timetableId: timetableId ?? this.timetableId,
      gradeId: gradeId ?? this.gradeId,
      section: section ?? this.section,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      location: location ?? this.location,
      notes: notes ?? this.notes,
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
            // Simple time comparison (assumes HH:MM AM/PM format)
            if (entry1.startTime == entry2.startTime) {
              conflicts.add(
                'Conflict: Grade ${entry1.gradeId}-${entry1.section} has ${entry1.subjectName} and ${entry2.subjectName} at same time',
              );
            }
          }
        }
      }
    }
    return conflicts;
  }
}
