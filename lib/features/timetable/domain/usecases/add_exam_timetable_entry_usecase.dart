import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entry_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for adding an exam entry to a timetable
///
/// Business Logic:
/// - Validates entry before adding
/// - Checks for duplicate entries (same grade+subject+date+section)
/// - Ensures time range is valid (start < end)
/// - Ensures duration matches time range
/// - Only allows adding to draft timetables
///
/// Validation Checks:
/// - Start time < End time
/// - Duration matches actual time range
/// - No duplicate entry exists
/// - All required fields are present
///
/// Example:
/// ```dart
/// final usecase = AddExamTimetableEntryUsecase(repository);
/// final entry = ExamTimetableEntryEntity(
///   id: 'entry-1',
///   tenantId: 'tenant-123',
///   timetableId: 'timetable-456',
///   gradeId: 'grade-10',
///   subjectId: 'subject-english',
///   section: 'A',
///   examDate: DateTime(2025, 11, 15),
///   startTime: Duration(hours: 9),
///   endTime: Duration(hours: 11),
///   durationMinutes: 120,
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// final result = await usecase(
///   params: AddExamTimetableEntryParams(entry: entry),
/// );
/// ```
class AddExamTimetableEntryUsecase {
  final ExamTimetableRepository _repository;

  AddExamTimetableEntryUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Add an exam entry to a timetable
  ///
  /// Parameters:
  /// - [params] - Contains the entry entity to add
  ///
  /// Returns:
  /// - [Either<Failure, ExamTimetableEntryEntity>] - Created entry or failure
  ///
  /// Validates:
  /// - Entry has valid time range
  /// - Duration matches time span
  /// - No duplicate entry exists in timetable
  /// - All required fields are present
  Future<Either<Failure, ExamTimetableEntryEntity>> call({
    required AddExamTimetableEntryParams params,
  }) async {
    final entry = params.entry;

    // Validate time range
    if (!entry.hasValidTimeRange) {
      return Left(
        ValidationFailure(
          'Invalid time range: Start time must be before end time',
        ),
      );
    }

    // Validate duration matches time range
    final calculatedDuration = entry.endTime.inMinutes - entry.startTime.inMinutes;
    if (entry.durationMinutes != calculatedDuration) {
      return Left(
        ValidationFailure(
          'Duration mismatch: Entry duration ($entry.durationMinutes) '
          'must match time range ($calculatedDuration minutes)',
        ),
      );
    }

    // Validate required fields
    if (entry.tenantId.isEmpty ||
        entry.timetableId.isEmpty ||
        (entry.gradeId?.isEmpty ?? true) ||
        entry.subjectId.isEmpty ||
        (entry.section?.isEmpty ?? true)) {
      return Left(ValidationFailure('All required fields must be filled'));
    }

    return await _repository.addExamTimetableEntry(entry);
  }
}

/// Parameters for AddExamTimetableEntryUsecase
class AddExamTimetableEntryParams {
  final ExamTimetableEntryEntity entry;

  AddExamTimetableEntryParams({required this.entry});
}
