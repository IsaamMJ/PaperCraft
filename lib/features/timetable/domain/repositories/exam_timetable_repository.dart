import 'package:dartz/dartz.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_calendar_entity.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_calendar_grade_mapping_entity.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entity.dart';
import 'package:papercraft/features/timetable/domain/entities/exam_timetable_entry_entity.dart';

/// Abstract repository for exam timetable operations.
/// Defines all business logic methods for managing exam calendars, timetables, and entries.
///
/// Returns Either<Failure, T> for functional error handling using dartz package.
/// This allows clean separation between success and failure cases.
abstract class ExamTimetableRepository {
  // ===== EXAM CALENDAR OPERATIONS =====

  /// Get all exam calendars for a tenant
  ///
  /// Returns list of active calendars sorted by display_order
  Future<Either<Failure, List<ExamCalendarEntity>>> getExamCalendars(
    String tenantId,
  );

  /// Get a specific exam calendar by ID
  Future<Either<Failure, ExamCalendarEntity>> getExamCalendarById(
    String calendarId,
  );

  /// Create a new exam calendar
  ///
  /// Validates that:
  /// - examName is not empty
  /// - plannedStartDate <= plannedEndDate
  /// - monthNumber is 1-12
  Future<Either<Failure, ExamCalendarEntity>> createExamCalendar(
    ExamCalendarEntity calendar,
  );

  /// Update an existing exam calendar
  ///
  /// Only admin users can update calendars (enforced at RLS level)
  Future<Either<Failure, ExamCalendarEntity>> updateExamCalendar(
    ExamCalendarEntity calendar,
  );

  /// Soft delete an exam calendar (sets is_active to false)
  ///
  /// Data is preserved, just hidden from users
  Future<Either<Failure, void>> deleteExamCalendar(String calendarId);

  /// Reactivate a soft-deleted calendar
  Future<Either<Failure, ExamCalendarEntity>> reactivateExamCalendar(
    String calendarId,
  );

  // ===== EXAM TIMETABLE OPERATIONS =====

  /// Get all exam timetables for a tenant, optionally filtered by academic year
  ///
  /// Returns timetables sorted by academic_year DESC
  Future<Either<Failure, List<ExamTimetableEntity>>> getExamTimetables(
    String tenantId, {
    String? academicYear,
  });

  /// Get a specific exam timetable by ID
  ///
  /// Includes all metadata and status information
  Future<Either<Failure, ExamTimetableEntity>> getExamTimetableById(
    String timetableId,
  );

  /// Create a new exam timetable (starts in draft status)
  ///
  /// Validates:
  /// - academicYear format (e.g., "2025-2026")
  /// - examName is not empty
  /// - createdBy is valid user ID
  Future<Either<Failure, ExamTimetableEntity>> createExamTimetable(
    ExamTimetableEntity timetable,
  );

  /// Update an existing exam timetable (only if in draft status)
  ///
  /// Prevents updates to published or archived timetables
  /// (This is a business logic check; RLS handles authorization)
  Future<Either<Failure, ExamTimetableEntity>> updateExamTimetable(
    ExamTimetableEntity timetable,
  );

  /// Publish an exam timetable (draft → published)
  ///
  /// Sets status to 'published' and publishedAt timestamp
  /// Once published, entries cannot be modified (Phase 2 feature)
  Future<Either<Failure, ExamTimetableEntity>> publishExamTimetable(
    String timetableId,
  );

  /// Archive an exam timetable (published → archived)
  ///
  /// Archived timetables are read-only, kept for records
  Future<Either<Failure, ExamTimetableEntity>> archiveExamTimetable(
    String timetableId,
  );

  /// Soft delete an exam timetable (sets is_active to false)
  ///
  /// Only draft timetables can be deleted
  Future<Either<Failure, void>> deleteExamTimetable(String timetableId);

  /// Reactivate a soft-deleted timetable
  Future<Either<Failure, ExamTimetableEntity>> reactivateExamTimetable(
    String timetableId,
  );

  // ===== EXAM TIMETABLE ENTRY OPERATIONS =====

  /// Get all entries for a specific timetable
  ///
  /// Returns entries sorted by exam_date ASC
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      getExamTimetableEntries(
    String timetableId,
  );

  /// Get a specific exam timetable entry by ID
  Future<Either<Failure, ExamTimetableEntryEntity>> getExamTimetableEntryById(
    String entryId,
  );

  /// Add a new exam entry to a timetable
  ///
  /// Validates:
  /// - startTime < endTime
  /// - durationMinutes matches time range
  /// - No duplicate (grade+subject+date) in same timetable
  /// - Timetable is in draft status
  Future<Either<Failure, ExamTimetableEntryEntity>> addExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  );

  /// Update an existing exam entry (only if timetable is draft)
  ///
  /// Validates same constraints as addExamTimetableEntry
  /// Prevents updates to entries in published timetables
  Future<Either<Failure, ExamTimetableEntryEntity>> updateExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  );

  /// Soft delete an exam entry (sets is_active to false)
  ///
  /// Only entries in draft timetables can be deleted
  Future<Either<Failure, void>> deleteExamTimetableEntry(String entryId);

  /// Reactivate a soft-deleted entry
  Future<Either<Failure, ExamTimetableEntryEntity>>
      reactivateExamTimetableEntry(String entryId);

  /// Add multiple entries in one operation (bulk insert)
  ///
  /// Used for importing or creating timetables with many entries
  /// Returns all successfully created entries
  /// Rolls back on first validation error (transactional)
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      addMultipleExamTimetableEntries(
    List<ExamTimetableEntryEntity> entries,
  );

  // ===== VALIDATION & UTILITY OPERATIONS =====

  /// Check if a grade+subject+date combination already exists in timetable
  ///
  /// Returns true if duplicate exists, false otherwise
  /// Used for real-time validation in UI
  Future<Either<Failure, bool>> checkDuplicateEntry(
    String timetableId,
    String gradeId,
    String subjectId,
    DateTime examDate,
    String section,
  );

  /// Get all duplicate entries for a timetable (for debugging/audit)
  ///
  /// Returns entries that violate unique constraint
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      getDuplicateEntries(String timetableId);

  /// Get statistics about a timetable
  ///
  /// Returns map with:
  /// - total_entries: int
  /// - active_entries: int
  /// - draft_entries: int (if applicable)
  /// - date_range: {start: DateTime, end: DateTime}
  /// - grades_covered: List<String>
  /// - subjects_covered: List<String>
  Future<Either<Failure, Map<String, dynamic>>> getExamTimetableStats(
    String timetableId,
  );

  /// Validate complete timetable before publishing
  ///
  /// Checks:
  /// - No duplicate entries
  /// - All entries have valid time ranges
  /// - All required fields filled
  /// - At least one entry exists
  ///
  /// Returns list of validation errors (empty if valid)
  Future<Either<Failure, List<String>>> validateExamTimetable(
    String timetableId,
  );

  /// Duplicate a timetable (copy structure for new academic year)
  ///
  /// Creates new timetable with same structure but:
  /// - New ID
  /// - New academicYear (must be provided)
  /// - Status: draft
  /// - New timestamps
  /// - Can adjust exam dates via dateOffset
  ///
  /// Returns newly created timetable
  Future<Either<Failure, ExamTimetableEntity>> duplicateExamTimetable(
    String sourceTimetableId,
    String newAcademicYear, {
    Duration? dateOffset,
  });

  // ===== EXAM CALENDAR GRADE SECTION MAPPING OPERATIONS (STEP 2) =====

  /// Get all grade sections mapped to an exam calendar
  ///
  /// Returns list of grade section IDs that are associated with a specific calendar
  /// Used in Step 2 to show which grade sections are already selected
  Future<Either<Failure, List<String>>> getGradesForCalendar(
    String examCalendarId,
  );

  /// Map grade sections to an exam calendar (Step 2 operation)
  ///
  /// Creates mappings for all provided grade sections to the calendar
  /// Returns all created mappings
  /// Used when user selects grade sections in Step 2
  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>>
      mapGradesToExamCalendar(
    String tenantId,
    String examCalendarId,
    List<String> gradeSectionIds,
  );

  /// Remove grade sections from an exam calendar
  ///
  /// Soft deletes the mappings
  Future<Either<Failure, void>> removeGradesFromCalendar(
    String examCalendarId,
    List<String> gradeSectionIds,
  );

  /// Create exam timetable with all entries in a single transaction
  ///
  /// Final step of wizard - creates the timetable with all subject-to-date mappings
  /// Returns the created timetable entity
  Future<Either<Failure, ExamTimetableEntity>>
      createExamTimetableWithEntries({
    required String tenantId,
    String? examCalendarId,
    required String examName,
    required String examType,
    required String academicYear,
    required String createdByUserId,
    required List<ExamTimetableEntryEntity> entries,
  });
}
