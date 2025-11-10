import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for fetching all exam timetables for a tenant
///
/// Business Logic:
/// - Retrieves active timetables only
/// - Optionally filters by academic year
/// - Returns timetables sorted by creation date (newest first)
///
/// Example:
/// ```dart
/// final usecase = GetExamTimetablesUsecase(repository);
/// final result = await usecase(
///   params: GetExamTimetablesParams(
///     tenantId: 'tenant-123',
///     academicYear: '2025-2026', // Optional
///   ),
/// );
/// ```
class GetExamTimetablesUsecase {
  final ExamTimetableRepository _repository;

  GetExamTimetablesUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Fetch all exam timetables for a tenant
  ///
  /// Parameters:
  /// - [params] - Contains tenantId and optional academicYear filter
  ///
  /// Returns:
  /// - [Either<Failure, List<ExamTimetableEntity>>] - List of timetables or failure
  Future<Either<Failure, List<ExamTimetableEntity>>> call({
    required GetExamTimetablesParams params,
  }) async {
    return await _repository.getExamTimetables(
      params.tenantId,
      academicYear: params.academicYear,
    );
  }
}

/// Parameters for GetExamTimetablesUsecase
class GetExamTimetablesParams {
  final String tenantId;
  final String? academicYear;

  GetExamTimetablesParams({
    required this.tenantId,
    this.academicYear,
  });
}
