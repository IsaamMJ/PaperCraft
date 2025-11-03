import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entry.dart';

/// Validation error details
class TimetableValidationError {
  final String field;
  final String message;
  final String? severity; // 'error', 'warning'

  TimetableValidationError({
    required this.field,
    required this.message,
    this.severity = 'error',
  });

  @override
  String toString() => '$field: $message';
}

/// Service for validating timetables
///
/// Validates:
/// 1. Timetable has at least 1 entry
/// 2. All entries have valid dates (future)
/// 3. All entries have valid times (start < end)
/// 4. No scheduling conflicts (same grade/section same day, same time)
/// 5. All entries have durations > 0
abstract class TimetableValidationService {
  /// Validate timetable entries
  ///
  /// Returns:
  /// - Right(emptyList) if valid
  /// - Right(errorList) if has validation errors
  /// - Left(Failure) if system error
  Future<Either<Failure, List<TimetableValidationError>>> validateEntries(
    List<ExamTimetableEntry> entries,
  );

  /// Check for scheduling conflicts
  ///
  /// Conflicts = same grade+section on same date+time range
  Future<Either<Failure, List<String>>> checkSchedulingConflicts(
    List<ExamTimetableEntry> entries,
  );

  /// Validate a single entry
  Future<Either<Failure, List<TimetableValidationError>>> validateEntry(
    ExamTimetableEntry entry,
  );
}
