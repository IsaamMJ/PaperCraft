import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../domain/repositories/exam_timetable_repository.dart';
import '../datasources/exam_timetable_remote_data_source.dart';

/// Implementation of ExamTimetableRepository using remote datasource
///
/// Acts as a bridge between the domain layer (business logic) and data layer (Supabase).
/// All operations delegate to the ExamTimetableRemoteDataSource which handles API calls.
///
/// The repository pattern provides:
/// - Abstraction of data sources (can swap implementations)
/// - Single responsibility (coordinate data fetching and error handling)
/// - Consistent interface for use cases
class ExamTimetableRepositoryImpl implements ExamTimetableRepository {
  final ExamTimetableRemoteDataSource _remoteDataSource;

  ExamTimetableRepositoryImpl({
    required ExamTimetableRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  // ===== EXAM CALENDAR OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamCalendarEntity>>> getExamCalendars(
    String tenantId,
  ) async {
    return await _remoteDataSource.getExamCalendars(tenantId);
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> getExamCalendarById(
    String calendarId,
  ) async {
    return await _remoteDataSource.getExamCalendarById(calendarId);
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> createExamCalendar(
    ExamCalendarEntity calendar,
  ) async {
    return await _remoteDataSource.createExamCalendar(calendar);
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> updateExamCalendar(
    ExamCalendarEntity calendar,
  ) async {
    return await _remoteDataSource.updateExamCalendar(calendar);
  }

  @override
  Future<Either<Failure, void>> deleteExamCalendar(String calendarId) async {
    return await _remoteDataSource.deleteExamCalendar(calendarId);
  }

  @override
  Future<Either<Failure, ExamCalendarEntity>> reactivateExamCalendar(
    String calendarId,
  ) async {
    return await _remoteDataSource.reactivateExamCalendar(calendarId);
  }

  // ===== EXAM TIMETABLE OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamTimetableEntity>>> getExamTimetables(
    String tenantId, {
    String? academicYear,
  }) async {
    return await _remoteDataSource.getExamTimetables(tenantId, academicYear: academicYear);
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> getExamTimetableById(
    String timetableId,
  ) async {
    return await _remoteDataSource.getExamTimetableById(timetableId);
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> createExamTimetable(
    ExamTimetableEntity timetable,
  ) async {
    return await _remoteDataSource.createExamTimetable(timetable);
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> updateExamTimetable(
    ExamTimetableEntity timetable,
  ) async {
    // Business logic check: only allow updates to draft timetables
    if (!timetable.isDraft) {
      return Left(
        ValidationFailure(
          'Cannot update a ${timetable.status} timetable. Only draft timetables can be modified.',
        ),
      );
    }

    return await _remoteDataSource.updateExamTimetable(timetable);
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> publishExamTimetable(
    String timetableId,
  ) async {
    // Validate before publishing
    final validationResult = await validateExamTimetable(timetableId);

    if (validationResult.isLeft()) {
      return validationResult.fold(
        (failure) => Left(failure),
        (_) => Right(ExamTimetableEntity(
          id: '', tenantId: '', createdBy: '', examName: '',
          examType: '', academicYear: '', createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )),
      );
    }

    return validationResult.fold(
      (failure) => Left<Failure, ExamTimetableEntity>(failure),
      (errors) {
        if (errors.isNotEmpty) {
          return Left<Failure, ExamTimetableEntity>(
            ValidationFailure(
              'Cannot publish timetable. Issues found:\n${errors.join('\n')}',
            ),
          );
        }
        return _remoteDataSource.publishExamTimetable(timetableId);
      },
    );
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> archiveExamTimetable(
    String timetableId,
  ) async {
    return await _remoteDataSource.archiveExamTimetable(timetableId);
  }

  @override
  Future<Either<Failure, void>> deleteExamTimetable(String timetableId) async {
    // Get the timetable first to check status
    final timetableResult = await _remoteDataSource.getExamTimetableById(timetableId);

    return await timetableResult.fold(
      (failure) => Left(failure),
      (timetable) async {
        // Business logic check: only allow deletion of draft timetables
        if (!timetable.isDraft) {
          return Left(
            ValidationFailure(
              'Cannot delete a ${timetable.status} timetable. Only draft timetables can be deleted.',
            ),
          );
        }
        return await _remoteDataSource.deleteExamTimetable(timetableId);
      },
    );
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> reactivateExamTimetable(
    String timetableId,
  ) async {
    return await _remoteDataSource.reactivateExamTimetable(timetableId);
  }

  // ===== EXAM TIMETABLE ENTRY OPERATIONS =====

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> getExamTimetableEntries(
    String timetableId,
  ) async {
    return await _remoteDataSource.getExamTimetableEntries(timetableId);
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> getExamTimetableEntryById(
    String entryId,
  ) async {
    return await _remoteDataSource.getExamTimetableEntryById(entryId);
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> addExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  ) async {
    // Validate entry
    final validation = _validateEntry(entry);
    if (validation != null) {
      return Left(validation);
    }

    // Check for duplicate
    final duplicate = await checkDuplicateEntry(
      entry.timetableId,
      entry.gradeId,
      entry.subjectId,
      entry.examDate,
      entry.section,
    );

    return await duplicate.fold(
      (failure) => Left(failure),
      (exists) {
        if (exists) {
          return Future.value(
            Left(
              ValidationFailure(
                'An entry for this grade, subject, section, and date already exists.',
              ),
            ),
          );
        }
        return _remoteDataSource.addExamTimetableEntry(entry);
      },
    );
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> updateExamTimetableEntry(
    ExamTimetableEntryEntity entry,
  ) async {
    // Validate entry
    final validation = _validateEntry(entry);
    if (validation != null) {
      return Left(validation);
    }

    return await _remoteDataSource.updateExamTimetableEntry(entry);
  }

  @override
  Future<Either<Failure, void>> deleteExamTimetableEntry(
    String entryId,
  ) async {
    return await _remoteDataSource.deleteExamTimetableEntry(entryId);
  }

  @override
  Future<Either<Failure, ExamTimetableEntryEntity>> reactivateExamTimetableEntry(
    String entryId,
  ) async {
    return await _remoteDataSource.reactivateExamTimetableEntry(entryId);
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>>
      addMultipleExamTimetableEntries(
    List<ExamTimetableEntryEntity> entries,
  ) async {
    // Validate all entries
    for (final entry in entries) {
      final validation = _validateEntry(entry);
      if (validation != null) {
        return Left(validation);
      }
    }

    // Check for duplicates within the batch
    final seen = <String>{};
    for (final entry in entries) {
      final key =
          '${entry.timetableId}_${entry.gradeId}_${entry.subjectId}_${entry.section}_${entry.examDate}';
      if (seen.contains(key)) {
        return Left(
          ValidationFailure('Duplicate entries found within the batch.'),
        );
      }
      seen.add(key);
    }

    return await _remoteDataSource.addMultipleExamTimetableEntries(entries);
  }

  // ===== VALIDATION & UTILITY OPERATIONS =====

  @override
  Future<Either<Failure, bool>> checkDuplicateEntry(
    String timetableId,
    String gradeId,
    String subjectId,
    DateTime examDate,
    String section,
  ) async {
    return await _remoteDataSource.checkDuplicateEntry(
      timetableId,
      gradeId,
      subjectId,
      examDate,
      section,
    );
  }

  @override
  Future<Either<Failure, List<ExamTimetableEntryEntity>>> getDuplicateEntries(
    String timetableId,
  ) async {
    return await _remoteDataSource.getDuplicateEntries(timetableId);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getExamTimetableStats(
    String timetableId,
  ) async {
    return await _remoteDataSource.getExamTimetableStats(timetableId);
  }

  @override
  Future<Either<Failure, List<String>>> validateExamTimetable(
    String timetableId,
  ) async {
    return await _remoteDataSource.validateExamTimetable(timetableId);
  }

  @override
  Future<Either<Failure, ExamTimetableEntity>> duplicateExamTimetable(
    String sourceTimetableId,
    String newAcademicYear, {
    Duration? dateOffset,
  }) async {
    return await _remoteDataSource.duplicateExamTimetable(
      sourceTimetableId,
      newAcademicYear,
      dateOffset: dateOffset,
    );
  }

  // ===== PRIVATE VALIDATION METHODS =====

  /// Validate an exam timetable entry
  ///
  /// Returns null if valid, or a Failure if invalid
  Failure? _validateEntry(ExamTimetableEntryEntity entry) {
    // Check: start time < end time
    if (!entry.hasValidTimeRange) {
      return ValidationFailure(
        'Invalid time range: Start time (${entry.startTimeDisplay}) '
        'must be before end time (${entry.endTimeDisplay})',
      );
    }

    // Check: required fields
    if (entry.id.isEmpty ||
        entry.tenantId.isEmpty ||
        entry.timetableId.isEmpty ||
        entry.gradeId.isEmpty ||
        entry.subjectId.isEmpty ||
        entry.section.isEmpty) {
      return ValidationFailure('All required fields must be filled');
    }

    // Check: duration matches time range
    final calculatedDuration = entry.endTime.inMinutes - entry.startTime.inMinutes;
    if (entry.durationMinutes != calculatedDuration) {
      return ValidationFailure(
        'Duration mismatch: Expected ${entry.durationMinutes} minutes '
        'but times span $calculatedDuration minutes',
      );
    }

    return null;
  }
}
