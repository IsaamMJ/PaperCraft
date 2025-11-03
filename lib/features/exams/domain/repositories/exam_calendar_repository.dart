
import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_calendar.dart';

/// Repository for managing exam calendar (yearly planning)
///
/// Handles planned exams like:
/// - June Monthly Test
/// - September Quarterly Test
/// - December Half-Yearly
/// - May Final Exam
///
/// Note: Daily tests are NOT in calendar (created ad-hoc in timetables)
abstract class ExamCalendarRepository {
  /// Get all exams in the calendar for a tenant
  ///
  /// [tenantId] - the school/tenant ID
  /// [academicYear] - optional, filter by academic year
  /// [activeOnly] - if true, only return is_active = true records
  /// [sortByMonth] - if true, sort by month_number for display
  Future<Either<Failure, List<ExamCalendar>>> getExamCalendars({
    required String tenantId,
    String? academicYear,
    bool activeOnly = true,
    bool sortByMonth = true,
  });

  /// Get a single exam calendar by ID
  Future<Either<Failure, ExamCalendar?>> getExamCalendarById(String id);

  /// Get exam calendar by name
  ///
  /// Used when creating timetable from calendar:
  /// Admin selects "June Monthly Test" → lookup to get full details
  Future<Either<Failure, ExamCalendar?>> getExamCalendarByName({
    required String tenantId,
    required String examName,
  });

  /// Create a new exam in the calendar
  ///
  /// Example: Add "June Monthly Test" to school's calendar
  /// Returns the created exam with ID assigned by database
  Future<Either<Failure, ExamCalendar>> createExamCalendar(
    ExamCalendar calendar,
  );

  /// Update an existing exam calendar entry
  ///
  /// Example: Change deadline date for June Monthly Test
  Future<Either<Failure, void>> updateExamCalendar(ExamCalendar calendar);

  /// Soft delete an exam from the calendar
  ///
  /// Note: Uses soft delete, so historical data is preserved
  /// Timetables created from this calendar remain valid
  Future<Either<Failure, void>> deleteExamCalendar(String id);

  /// Get exams for a specific month
  ///
  /// Used for month-based filtering in UI
  /// Returns exams that occur in [monthNumber] (1-12)
  Future<Either<Failure, List<ExamCalendar>>> getExamsForMonth({
    required String tenantId,
    required int monthNumber,
    bool activeOnly = true,
  });

  /// Get upcoming exams (planned_start_date is in the future)
  ///
  /// Used to show relevant exams in dashboard
  Future<Either<Failure, List<ExamCalendar>>> getUpcomingExams({
    required String tenantId,
    bool activeOnly = true,
  });

  /// Check if exam name already exists
  ///
  /// Used during creation to prevent duplicates
  Future<Either<Failure, bool>> examNameExists({
    required String tenantId,
    required String examName,
  });
}
