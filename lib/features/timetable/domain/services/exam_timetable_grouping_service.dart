import '../../../exams/domain/entities/exam_timetable_entry.dart';

/// Service to group exam timetable entries by subject and teacher
/// This ensures Step 3 preview matches actual paper creation
class ExamTimetableGroupingService {
  /// Group entries by (gradeId, subjectId, teacher) and combine sections
  ///
  /// ONLY combines if:
  /// 1. Same subject + same teacher for different sections in same grade
  /// 2. Teacher is actually assigned (not "No teacher assigned")
  ///
  /// If different teachers OR no teacher assigned: Keep separate
  ///
  /// Also returns updated entryTeacherNames map for grouped entries
  static Map<String, dynamic> groupEntriesBySubjectAndTeacherWithMapping(
      List<ExamTimetableEntry> entries,
      Map<String, String> entryTeacherNames,
      ) {
    // Group by (gradeId, subjectId, teacher)
    final grouped = <String, List<ExamTimetableEntry>>{};
    final entryToTeacherMap = <String, String>{}; // Maps new grouped entry keys to teacher names

    for (final entry in entries) {
      final entryKey = '${entry.gradeId}_${entry.subjectId}_${entry.section}';
      final teacherName = entryTeacherNames[entryKey] ?? '';

      // IMPORTANT: Only group if teacher is assigned (not "No teacher assigned")
      final hasValidTeacher = teacherName.isNotEmpty &&
          !teacherName.contains('No teacher') &&
          teacherName != 'Loading...';

      // Create group key: grade_subject_teacher (only if teacher is assigned)
      final groupKey = hasValidTeacher
          ? '${entry.gradeId}_${entry.subjectId}_$teacherName'
          : '${entry.gradeId}_${entry.subjectId}_${entry.section}'; // Keep sections separate if no teacher

      grouped.putIfAbsent(groupKey, () => []).add(entry);
    }

    // Combine entries in each group
    final result = <ExamTimetableEntry>[];

    for (final groupEntries in grouped.values) {
      if (groupEntries.length == 1) {
        // Single entry, no combining needed
        final entry = groupEntries.first;
        final entryKey = '${entry.gradeId}_${entry.subjectId}_${entry.section}';
        final teacherName = entryTeacherNames[entryKey] ?? '';
        entryToTeacherMap[entryKey] = teacherName;
        result.add(entry);
      } else {
        // Multiple entries with SAME VALID TEACHER (different sections, same subject, same teacher)
        // Combine sections into one entry
        final firstEntry = groupEntries.first;
        final sections = groupEntries.map((e) => e.section).toList();
        final combinedSection = sections.join(', ');

        final combinedEntry = firstEntry.copyWith(
          section: combinedSection,
        );

        // Store teacher name for the combined entry using combined section key
        final combinedKey = '${combinedEntry.gradeId}_${combinedEntry.subjectId}_$combinedSection';
        final firstEntryKey = '${firstEntry.gradeId}_${firstEntry.subjectId}_${firstEntry.section}';
        final teacherName = entryTeacherNames[firstEntryKey] ?? '';
        entryToTeacherMap[combinedKey] = teacherName;

        result.add(combinedEntry);
      }
    }

    return {
      'entries': result,
      'entryTeacherNames': entryToTeacherMap,
    };
  }

  /// Legacy method - use groupEntriesBySubjectAndTeacherWithMapping instead
  static List<ExamTimetableEntry> groupEntriesBySubjectAndTeacher(
      List<ExamTimetableEntry> entries,
      Map<String, String> entryTeacherNames,
      ) {
    return (groupEntriesBySubjectAndTeacherWithMapping(entries, entryTeacherNames)['entries']
        as List<ExamTimetableEntry>?) ?? entries;
  }
}
