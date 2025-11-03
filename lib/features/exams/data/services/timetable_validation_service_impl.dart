import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_timetable_entry.dart';
import '../../domain/services/timetable_validation_service.dart';

/// Implementation of TimetableValidationService
class TimetableValidationServiceImpl implements TimetableValidationService {
  @override
  Future<Either<Failure, List<TimetableValidationError>>> validateEntries(
    List<ExamTimetableEntry> entries,
  ) async {
    try {
      final errors = <TimetableValidationError>[];

      if (entries.isEmpty) {
        errors.add(
          TimetableValidationError(
            field: 'entries',
            message: 'Timetable must have at least 1 entry',
            severity: 'error',
          ),
        );
        return Right(errors);
      }

      // Validate each entry
      for (final entry in entries) {
        // Check if exam date is in future
        if (entry.examDate.isBefore(DateTime.now())) {
          errors.add(
            TimetableValidationError(
              field: 'examDate',
              message: 'Exam date must be in the future (${entry.displayName})',
              severity: 'error',
            ),
          );
        }

        // Check start time < end time
        final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
        final endMinutes = entry.endTime.hour * 60 + entry.endTime.minute;

        if (startMinutes >= endMinutes) {
          errors.add(
            TimetableValidationError(
              field: 'times',
              message: 'Start time must be before end time (${entry.displayName})',
              severity: 'error',
            ),
          );
        }

        // Check duration > 0
        if (entry.durationMinutes <= 0) {
          errors.add(
            TimetableValidationError(
              field: 'duration',
              message: 'Exam duration must be greater than 0 (${entry.displayName})',
              severity: 'error',
            ),
          );
        }
      }

      // Check for scheduling conflicts
      final conflicts = await checkSchedulingConflicts(entries);
      final conflictList = conflicts.fold(
        (failure) => <String>[],
        (conflicts) => conflicts,
      );

      if (conflictList.isNotEmpty) {
        for (final conflict in conflictList) {
          errors.add(
            TimetableValidationError(
              field: 'scheduling',
              message: conflict,
              severity: 'warning',
            ),
          );
        }
      }

      return Right(errors);
    } catch (e) {
      return Left(
        ServerFailure('Validation error: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<String>>> checkSchedulingConflicts(
    List<ExamTimetableEntry> entries,
  ) async {
    try {
      final conflicts = <String>[];

      // Check for same grade+section on same date at overlapping times
      for (int i = 0; i < entries.length; i++) {
        for (int j = i + 1; j < entries.length; j++) {
          final entry1 = entries[i];
          final entry2 = entries[j];

          // Skip if not same grade+section
          if (entry1.gradeId != entry2.gradeId || entry1.section != entry2.section) {
            continue;
          }

          // Skip if different dates
          if (entry1.examDate.year != entry2.examDate.year ||
              entry1.examDate.month != entry2.examDate.month ||
              entry1.examDate.day != entry2.examDate.day) {
            continue;
          }

          // Check for time overlap
          final start1 = entry1.startTime.hour * 60 + entry1.startTime.minute;
          final end1 = entry1.endTime.hour * 60 + entry1.endTime.minute;
          final start2 = entry2.startTime.hour * 60 + entry2.startTime.minute;
          final end2 = entry2.endTime.hour * 60 + entry2.endTime.minute;

          // Times overlap if: start1 < end2 AND start2 < end1
          if (start1 < end2 && start2 < end1) {
            conflicts.add(
              'Scheduling conflict: ${entry1.displayName} and ${entry2.displayName} '
              'overlap on ${entry1.formattedDate}',
            );
          }
        }
      }

      return Right(conflicts);
    } catch (e) {
      return Left(
        ServerFailure('Failed to check scheduling conflicts: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<TimetableValidationError>>> validateEntry(
    ExamTimetableEntry entry,
  ) async {
    try {
      final errors = <TimetableValidationError>[];

      // Check if exam date is in future
      if (entry.examDate.isBefore(DateTime.now())) {
        errors.add(
          TimetableValidationError(
            field: 'examDate',
            message: 'Exam date must be in the future',
            severity: 'error',
          ),
        );
      }

      // Check start time < end time
      final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
      final endMinutes = entry.endTime.hour * 60 + entry.endTime.minute;

      if (startMinutes >= endMinutes) {
        errors.add(
          TimetableValidationError(
            field: 'times',
            message: 'Start time must be before end time',
            severity: 'error',
          ),
        );
      }

      // Check duration > 0
      if (entry.durationMinutes <= 0) {
        errors.add(
          TimetableValidationError(
            field: 'duration',
            message: 'Exam duration must be greater than 0',
            severity: 'error',
          ),
        );
      }

      return Right(errors);
    } catch (e) {
      return Left(
        ServerFailure('Validation error: ${e.toString()}'),
      );
    }
  }
}
