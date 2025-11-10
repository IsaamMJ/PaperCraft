import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for publishing an exam timetable
///
/// Business Logic:
/// - Validates timetable before publishing
/// - Only draft timetables can be published
/// - Sets status to 'published' and publishedAt timestamp
/// - Once published, entries are locked (read-only)
/// - Returns validation errors if timetable is invalid
///
/// Validation Checks:
/// - At least one entry exists
/// - No duplicate entries
/// - All entries have valid time ranges
/// - All required fields are filled
///
/// Example:
/// ```dart
/// final usecase = PublishExamTimetableUsecase(repository);
/// final result = await usecase(
///   params: PublishExamTimetableParams(timetableId: 'timetable-123'),
/// );
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (published) => print('Timetable published successfully'),
/// );
/// ```
class PublishExamTimetableUsecase {
  final ExamTimetableRepository _repository;

  PublishExamTimetableUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Publish an exam timetable
  ///
  /// Parameters:
  /// - [params] - Contains timetableId to publish
  ///
  /// Returns:
  /// - [Either<Failure, ExamTimetableEntity>] - Published timetable or failure
  ///
  /// Validates:
  /// - Timetable is in draft status
  /// - Timetable has at least one entry
  /// - No duplicate entries exist
  /// - All entries have valid time ranges
  /// - All required fields are complete
  Future<Either<Failure, ExamTimetableEntity>> call({
    required PublishExamTimetableParams params,
  }) async {
    return await _repository.publishExamTimetable(params.timetableId);
  }
}

/// Parameters for PublishExamTimetableUsecase
class PublishExamTimetableParams {
  final String timetableId;

  PublishExamTimetableParams({required this.timetableId});
}
