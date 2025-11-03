import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case: Validate timetable before publishing
///
/// Called by: PublishExamTimetableUseCase (before publishing)
/// Also called by: Admin UI to show validation status in confirmation dialog
///
/// Validates:
/// 1. Timetable has at least 1 entry
/// 2. Each entry has at least 1 teacher assigned
/// 3. No scheduling conflicts (optional)
///
/// Returns list of validation errors (empty = valid)
class ValidateTimetableForPublishingUseCase {
  final ExamTimetableRepository repository;

  ValidateTimetableForPublishingUseCase({required this.repository});

  /// Validate the timetable
  ///
  /// Returns Right(emptyList) if valid
  /// Returns Right(errorList) if has errors
  /// Returns Left(Failure) if system error
  Future<Either<Failure, List<ValidationError>>> call({
    required String timetableId,
  }) async {
    try {
      // This method is a placeholder - actual implementation
      // requires the repository to support it fully
      // For now, we return a note that it needs implementation

      final result = await repository.validateForPublishing(
        timetableId: timetableId,
      );

      return result;
    } on Exception catch (e) {
      return Left(
        ServerFailure('Validation failed: ${e.toString()}'),
      );
    }
  }
}
