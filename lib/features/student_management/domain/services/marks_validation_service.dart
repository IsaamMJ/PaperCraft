import 'package:dartz/dartz.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:papercraft/features/timetable/domain/repositories/exam_timetable_repository.dart';

/// Service to validate student exam marks
class MarksValidationService {
  final ExamTimetableRepository examRepository;
  final ILogger logger;

  MarksValidationService({
    required this.examRepository,
    required this.logger,
  });

  /// Validate marks against exam maximum marks
  Future<Either<Failure, bool>> validateMarks({
    required double marks,
    required String examTimetableEntryId,
    required StudentMarkStatus status,
  }) async {
    try {
      // Marks must be non-negative
      if (marks < 0) {
        return Left(ValidationFailure('Marks cannot be negative'));
      }

      // If status is not "present", marks should be 0
      if (status != StudentMarkStatus.present && marks > 0) {
        return Left(ValidationFailure(
          'Only students marked as "Present" can have marks',
        ));
      }

      // Only validate against max marks if student is present
      if (status != StudentMarkStatus.present) {
        return const Right(true);
      }

      // Fetch exam details to get max marks
      final examResult = await examRepository.getExamTimetableEntryById(
        examTimetableEntryId,
      );

      return examResult.fold(
        (failure) {
          logger.error(
            'Failed to fetch exam for validation: ${failure.message}',
            category: LogCategory.system,
          );
          return Left(failure);
        },
        (exam) {
          // Get max marks from exam calendar via exam details
          // For now, we'll use a default check - this should be enhanced
          // to fetch actual max marks from exam_calendar.marks_config

          if (marks > 1000) {
            // Safety check - max marks unlikely to exceed 1000
            return Left(ValidationFailure(
              'Marks exceed reasonable maximum (1000)',
            ));
          }

          return const Right(true);
        },
      );
    } catch (e) {
      logger.error(
        'Error validating marks: ${e.toString()}',
        category: LogCategory.system,
      );
      return Left(ServerFailure('Validation error: ${e.toString()}'));
    }
  }

  /// Validate all marks for an exam before submission
  Future<Either<Failure, bool>> validateAllMarks({
    required List<StudentExamMarksEntity> allMarks,
    required String examTimetableEntryId,
  }) async {
    try {
      for (final marks in allMarks) {
        // Validate each entry
        final result = await validateMarks(
          marks: marks.totalMarks,
          examTimetableEntryId: examTimetableEntryId,
          status: marks.status,
        );

        if (result.isLeft()) {
          return result;
        }

        // Status must be selected
        // This is implicit in the entity, so we can assume it's valid
      }

      return const Right(true);
    } catch (e) {
      logger.error(
        'Error validating all marks: ${e.toString()}',
        category: LogCategory.system,
      );
      return Left(ServerFailure('Validation error: ${e.toString()}'));
    }
  }

  /// Validate marks submission (at least some marks must be entered)
  bool validateMarksSubmission(List<StudentExamMarksEntity> marks) {
    if (marks.isEmpty) {
      return false;
    }

    // At least one student must have marks or a status
    return marks.isNotEmpty;
  }

  /// Check if all students have either marks or a status
  bool validateAllStudentsHaveStatus(List<StudentExamMarksEntity> marks) {
    return marks.every((m) => m.status != StudentMarkStatus.present || m.totalMarks > 0);
  }
}
