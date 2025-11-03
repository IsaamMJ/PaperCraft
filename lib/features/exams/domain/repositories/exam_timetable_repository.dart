
import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable.dart';
import '../entities/exam_timetable_entry.dart';

/// Repository for managing exam timetables and their entries
///
/// Handles:
/// 1. Timetable CRUD (create, read, update, delete)
/// 2. Timetable entry management (add, remove, list)
/// 3. Publishing timetables (status change + paper creation)
///
/// A timetable can be created:
/// - FROM exam_calendar: Pick from planned exams (June Monthly, etc.)
/// - AD-HOC: Create for daily tests (Week 1, Week 2, etc.)
abstract class ExamTimetableRepository {
  /// Create a new exam timetable
  ///
  /// Initial status is always "draft"
  /// Returns the created timetable with ID assigned by database
  Future<Either<Failure, ExamTimetable>> createTimetable(
    ExamTimetable timetable,
  );

  /// Get a timetable by ID
  Future<Either<Failure, ExamTimetable?>> getTimetableById(String id);

  /// Get all timetables for a tenant
  ///
  /// [tenantId] - the school/tenant ID
  /// [academicYear] - optional, filter by academic year
  /// [status] - optional, filter by status (draft, published, etc.)
  /// [activeOnly] - if true, only return is_active = true records
  Future<Either<Failure, List<ExamTimetable>>> getTimetablesForTenant({
    required String tenantId,
    String? academicYear,
    TimetableStatus? status,
    bool activeOnly = true,
  });

  /// Update timetable details (name, metadata, etc.)
  ///
  /// Note: Can only edit if status = draft
  /// Once published, timetable is read-only
  Future<Either<Failure, void>> updateTimetable(ExamTimetable timetable);

  /// Update only the status of a timetable
  ///
  /// Used during publishing workflow:
  /// 1. Validate entries
  /// 2. Create papers
  /// 3. Update status to "published" with publishedAt timestamp
  Future<Either<Failure, void>> updateTimetableStatus({
    required String timetableId,
    required TimetableStatus status,
    DateTime? publishedAt,
  });

  /// Soft delete a timetable
  ///
  /// Can only delete if status = draft
  /// Published timetables cannot be deleted (archive instead)
  Future<Either<Failure, void>> deleteTimetable(String timetableId);

  // ========== TIMETABLE ENTRIES METHODS ==========

  /// Add an entry to a timetable
  ///
  /// Entry = Grade 5-A, Maths, 2024-06-15, 09:00-10:30
  /// Creates the subject/grade/section/time combination
  ///
  /// Fails if:
  /// - Entry already exists for this timetable/grade/subject/section (unique constraint)
  /// - Grade/section doesn't exist
  /// - Start time >= End time
  Future<Either<Failure, ExamTimetableEntry>> addTimetableEntry(
    ExamTimetableEntry entry,
  );

  /// Get all entries for a timetable
  ///
  /// Returns list of all subject/grade/section/time combinations
  /// Used for publishing validation and display
  Future<Either<Failure, List<ExamTimetableEntry>>> getTimetableEntries(
    String timetableId,
  );

  /// Get entries filtered by grade
  ///
  /// Example: Show all entries for Grade 5 in this timetable
  Future<Either<Failure, List<ExamTimetableEntry>>> getTimetableEntriesByGrade({
    required String timetableId,
    required String gradeId,
  });

  /// Get a single entry by ID
  Future<Either<Failure, ExamTimetableEntry?>> getTimetableEntryById(String id);

  /// Update a timetable entry
  ///
  /// Can only edit if parent timetable status = draft
  Future<Either<Failure, void>> updateTimetableEntry(
    ExamTimetableEntry entry,
  );

  /// Remove an entry from a timetable
  ///
  /// Can only delete if parent timetable status = draft
  /// Soft delete (is_active = false)
  Future<Either<Failure, void>> removeTimetableEntry(String entryId);

  /// Count total entries in a timetable
  ///
  /// Used for display: "Timetable has 15 entries"
  Future<Either<Failure, int>> countTimetableEntries(String timetableId);

  /// Check if entry exists for (timetable, grade, subject, section)
  ///
  /// Used to prevent duplicates
  Future<Either<Failure, bool>> entryExists({
    required String timetableId,
    required String gradeId,
    required String subjectId,
    required String section,
  });

  // ========== VALIDATION METHODS ==========

  /// Count total papers that WILL be created if timetable is published
  ///
  /// Used for confirmation dialog:
  /// "Publishing will create X papers"
  ///
  /// For each entry: Count teachers assigned to (grade, subject, section)
  /// Sum up total paper count
  ///
  /// Also returns warnings like "No teacher for Grade 5-A Maths"
  Future<Either<Failure, PaperCountResult>> calculateExpectedPaperCount({
    required String timetableId,
  });

  /// Validate timetable before publishing
  ///
  /// Checks:
  /// 1. At least 1 entry exists
  /// 2. All entries have at least 1 teacher assigned
  /// 3. No scheduling conflicts (optional)
  ///
  /// Returns list of validation errors (empty = valid)
  Future<Either<Failure, List<ValidationError>>> validateForPublishing({
    required String timetableId,
  });
}

/// Result of calculating expected paper count
class PaperCountResult {
  final int totalExpectedPapers;
  final int entriesWithTeachers;
  final int entriesWithoutTeachers;
  final List<String> entriesWithoutTeachersNames;

  PaperCountResult({
    required this.totalExpectedPapers,
    required this.entriesWithTeachers,
    required this.entriesWithoutTeachers,
    required this.entriesWithoutTeachersNames,
  });

  bool get isValid => entriesWithoutTeachers == 0;
}

/// Validation error message
class ValidationError {
  final String field;
  final String message;

  ValidationError({
    required this.field,
    required this.message,
  });
}
