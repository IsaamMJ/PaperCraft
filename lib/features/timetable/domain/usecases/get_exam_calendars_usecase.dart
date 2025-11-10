import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_calendar_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for fetching all exam calendars for a tenant
///
/// Business Logic:
/// - Retrieves active exam calendars only
/// - Calendars are sorted by display_order
/// - Returns Either<Failure, List<ExamCalendarEntity>>
///
/// Example:
/// ```dart
/// final usecase = GetExamCalendarsUsecase(repository);
/// final result = await usecase(params: GetExamCalendarsParams(tenantId: 'tenant-123'));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (calendars) => print('Found ${calendars.length} calendars'),
/// );
/// ```
class GetExamCalendarsUsecase {
  final ExamTimetableRepository _repository;

  GetExamCalendarsUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  /// Fetch all exam calendars for a tenant
  ///
  /// Parameters:
  /// - [params] - Contains tenantId for filtering calendars
  ///
  /// Returns:
  /// - [Either<Failure, List<ExamCalendarEntity>>] - List of calendars or failure
  Future<Either<Failure, List<ExamCalendarEntity>>> call({
    required GetExamCalendarsParams params,
  }) async {
    return await _repository.getExamCalendars(params.tenantId);
  }
}

/// Parameters for GetExamCalendarsUsecase
class GetExamCalendarsParams {
  final String tenantId;

  GetExamCalendarsParams({required this.tenantId});
}
