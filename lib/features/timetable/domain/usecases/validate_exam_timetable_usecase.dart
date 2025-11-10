import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for validating an exam timetable before publishing
///
/// Business Logic:
/// - Validates complete timetable structure
/// - Checks for duplicate entries
/// - Validates time ranges
/// - Ensures at least one entry exists
/// - Returns list of validation errors (empty if valid)
///
/// Validation Checks:
/// - At least one entry exists
/// - No duplicate entries (same grade+subject+section+date)
/// - All entries have valid time ranges (start < end)
/// - All required fields are filled
///
/// Example:
/// ```dart
/// final usecase = ValidateExamTimetableUsecase(repository);
/// final result = await usecase(
///   params: ValidateExamTimetableParams(timetableId: 'timetable-123'),
/// );
/// result.fold(
///   (failure) => print('Validation failed: ${failure.message}'),
///   (errors) {
///     if (errors.isEmpty) {
///       print('Timetable is valid');
///     } else {
///       errors.forEach((error) => print('- $error'));
///     }
///   },
/// );
/// ```
class ValidateExamTimetableUsecase {
  final ExamTimetableRepository _repository;

  ValidateExamTimetableUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Validate an exam timetable
  ///
  /// Parameters:
  /// - [params] - Contains timetableId to validate
  ///
  /// Returns:
  /// - [Either<Failure, List<String>>] - List of validation errors or failure
  /// - Empty list means timetable is valid
  /// - Non-empty list contains validation error messages
  ///
  /// Validates:
  /// - Timetable has at least one entry
  /// - No duplicate entries exist
  /// - All entries have valid time ranges
  /// - All required fields are complete
  Future<Either<Failure, List<String>>> call({
    required ValidateExamTimetableParams params,
  }) async {
    return await _repository.validateExamTimetable(params.timetableId);
  }
}

/// Parameters for ValidateExamTimetableUsecase
class ValidateExamTimetableParams {
  final String timetableId;

  ValidateExamTimetableParams({required this.timetableId});
}
