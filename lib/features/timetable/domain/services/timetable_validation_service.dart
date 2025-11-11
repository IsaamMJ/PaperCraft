import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';

/// Validation result containing success status and error messages
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  /// Create a valid result (no errors)
  factory ValidationResult.valid() {
    return ValidationResult(isValid: true, errors: []);
  }

  /// Create an invalid result with errors
  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }

  /// Create a single error result
  factory ValidationResult.error(String error) {
    return ValidationResult(isValid: false, errors: [error]);
  }

  /// Add an error to this result
  ValidationResult addError(String error) {
    if (error.isNotEmpty) {
      errors.add(error);
    }
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

/// Service for validating exam timetables and entries
///
/// Provides comprehensive validation logic for:
/// - Timetable structure
/// - Entry format and content
/// - Time ranges and conflicts
/// - Duplicate detection
/// - Data completeness
class TimetableValidationService {
  /// Validate complete timetable for publishing
  ValidationResult validateTimetableForPublishing(
    ExamTimetableEntity timetable,
    List<ExamTimetableEntryEntity> entries,
  ) {
    final errors = <String>[];

    // Check basic timetable info
    errors.addAll(_validateTimetableInfo(timetable).errors);

    // Check entries exist
    if (entries.isEmpty) {
      errors.add('Timetable must have at least one exam entry');
    } else {
      // Validate each entry
      errors.addAll(_validateEntries(entries).errors);

      // Check for duplicates
      errors.addAll(_checkDuplicateEntries(entries).errors);

      // Check for time conflicts
      errors.addAll(_checkTimeConflicts(entries).errors);
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Validate timetable basic information
  ValidationResult _validateTimetableInfo(ExamTimetableEntity timetable) {
    final errors = <String>[];

    if (timetable.examName.isEmpty) {
      errors.add('Exam name cannot be empty');
    }

    if (timetable.examType.isEmpty) {
      errors.add('Exam type cannot be empty');
    }

    if (timetable.academicYear.isEmpty) {
      errors.add('Academic year cannot be empty');
    } else if (!_isValidAcademicYear(timetable.academicYear)) {
      errors.add('Academic year format invalid (use YYYY-YYYY)');
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Validate all entries
  ValidationResult _validateEntries(List<ExamTimetableEntryEntity> entries) {
    final errors = <String>[];
    final Set<String> entryIds = {};

    for (final entry in entries) {
      // Check for duplicate IDs
      if (entry.id != null && entryIds.contains(entry.id)) {
        errors.add('Duplicate entry ID: ${entry.id}');
        continue;
      }
      if (entry.id != null) {
        entryIds.add(entry.id!);
      }

      // Validate entry
      errors.addAll(_validateEntry(entry).errors);
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Validate single entry
  ValidationResult _validateEntry(ExamTimetableEntryEntity entry) {
    final errors = <String>[];
    final entryRef =
        'Entry: ${entry.subjectId} (Grade ${entry.gradeId}, Section ${entry.section})';

    // Validate required fields
    if ((entry.gradeId?.isEmpty ?? true)) {
      errors.add('$entryRef: Grade ID cannot be empty');
    }

    if (entry.subjectId.isEmpty) {
      errors.add('$entryRef: Subject ID cannot be empty');
    }

    if ((entry.section?.isEmpty ?? true)) {
      errors.add('$entryRef: Section cannot be empty');
    }

    // Validate time range
    if (!entry.hasValidTimeRange) {
      errors.add('$entryRef: Start time must be before end time');
    }

    // Validate duration
    if (entry.durationMinutes <= 0) {
      errors.add('$entryRef: Duration must be positive');
    }

    final expectedDuration = entry.endTime.inMinutes - entry.startTime.inMinutes;
    if (entry.durationMinutes != expectedDuration) {
      errors.add(
        '$entryRef: Duration mismatch (expected $expectedDuration min, got ${entry.durationMinutes} min)',
      );
    }

    // Validate exam date is not in the past
    final now = DateTime.now();
    if (entry.examDate.isBefore(DateTime(now.year, now.month, now.day))) {
      errors.add('$entryRef: Exam date cannot be in the past');
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Check for duplicate entries (same grade+subject+section+date)
  ValidationResult _checkDuplicateEntries(
    List<ExamTimetableEntryEntity> entries,
  ) {
    final errors = <String>[];
    final seen = <String, ExamTimetableEntryEntity>{};

    for (final entry in entries) {
      final key =
          '${entry.gradeId}_${entry.subjectId}_${entry.section}_${entry.examDate.toIso8601String().split('T')[0]}';

      if (seen.containsKey(key)) {
        final existing = seen[key]!;
        errors.add(
          'Duplicate entry: Grade ${entry.gradeId}, Subject ${entry.subjectId}, '
          'Section ${entry.section} on ${entry.examDateDisplay}. '
          'First entry: ${existing.startTimeDisplay}-${existing.endTimeDisplay}, '
          'Second entry: ${entry.startTimeDisplay}-${entry.endTimeDisplay}',
        );
      } else {
        seen[key] = entry;
      }
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Check for time conflicts in same grade on same day
  ValidationResult _checkTimeConflicts(
    List<ExamTimetableEntryEntity> entries,
  ) {
    final errors = <String>[];

    // Group entries by grade and date
    final Map<String, List<ExamTimetableEntryEntity>> gradeDay = {};

    for (final entry in entries) {
      final key =
          '${entry.gradeId}_${entry.examDate.toIso8601String().split('T')[0]}';
      gradeDay.putIfAbsent(key, () => []).add(entry);
    }

    // Check for overlaps within each grade-day
    for (final entries in gradeDay.values) {
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final entry1 = entries[i];
          final entry2 = entries[j];

          if (_timesOverlap(entry1, entry2)) {
            errors.add(
              'Time conflict: Grade ${entry1.gradeId} on ${entry1.examDateDisplay}: '
              '${entry1.subjectId} (${entry1.startTimeDisplay}-${entry1.endTimeDisplay}) '
              'overlaps with ${entry2.subjectId} (${entry2.startTimeDisplay}-${entry2.endTimeDisplay})',
            );
          }
        }
      }
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Check if two time ranges overlap
  bool _timesOverlap(
    ExamTimetableEntryEntity entry1,
    ExamTimetableEntryEntity entry2,
  ) {
    // Entries don't overlap if one ends before the other starts
    if (entry1.endTime.inMinutes <= entry2.startTime.inMinutes) {
      return false;
    }
    if (entry2.endTime.inMinutes <= entry1.startTime.inMinutes) {
      return false;
    }
    return true;
  }

  /// Validate academic year format (YYYY-YYYY)
  bool _isValidAcademicYear(String year) {
    final regex = RegExp(r'^\d{4}-\d{4}$');
    if (!regex.hasMatch(year)) return false;

    final parts = year.split('-');
    final start = int.tryParse(parts[0]);
    final end = int.tryParse(parts[1]);

    if (start == null || end == null) return false;
    if (end - start != 1) return false; // Must span exactly 1 year

    return true;
  }

  /// Validate single entry for real-time feedback
  ValidationResult validateEntryInput({
    required String gradeId,
    required String subjectId,
    required String section,
    required DateTime examDate,
    required Duration startTime,
    required Duration endTime,
  }) {
    final errors = <String>[];

    if (gradeId.isEmpty) {
      errors.add('Grade must be selected');
    }

    if (subjectId.isEmpty) {
      errors.add('Subject must be selected');
    }

    if (section.isEmpty) {
      errors.add('Section must be selected');
    }

    if (startTime >= endTime) {
      errors.add('Start time must be before end time');
    }

    final now = DateTime.now();
    if (examDate.isBefore(DateTime(now.year, now.month, now.day))) {
      errors.add('Exam date cannot be in the past');
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }
}
