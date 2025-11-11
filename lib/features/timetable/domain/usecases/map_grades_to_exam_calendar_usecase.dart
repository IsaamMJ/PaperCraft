import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_calendar_grade_mapping_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for Step 2: Map grade sections to an exam calendar
///
/// This use case allows users to select which grade sections will participate in an exam.
/// Called during Step 2 of the wizard after selecting the exam calendar.
///
/// Example:
/// ```dart
/// final params = MapGradesToExamCalendarParams(
///   tenantId: 'tenant-123',
///   examCalendarId: 'calendar-456',
///   gradeSectionIds: ['section-1', 'section-2', 'section-3'],
/// );
/// final result = await mapGradesToExamCalendar(params);
/// ```
class MapGradesToExamCalendarUsecase {
  final ExamTimetableRepository repository;

  MapGradesToExamCalendarUsecase({
    required this.repository,
  });

  Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>> call(
    MapGradesToExamCalendarParams params,
  ) async {
    // Validate inputs
    if (params.tenantId.isEmpty) {
      return Left(ValidationFailure('Tenant ID cannot be empty'));
    }
    if (params.examCalendarId.isEmpty) {
      return Left(ValidationFailure('Exam calendar ID cannot be empty'));
    }
    if (params.gradeSectionIds.isEmpty) {
      return Left(ValidationFailure('At least one grade section must be selected'));
    }

    // Call repository to map grade sections
    return await repository.mapGradesToExamCalendar(
      params.tenantId,
      params.examCalendarId,
      params.gradeSectionIds,
    );
  }
}

/// Parameters for MapGradesToExamCalendarUsecase
class MapGradesToExamCalendarParams extends Equatable {
  final String tenantId;
  final String examCalendarId;
  final List<String> gradeSectionIds;

  const MapGradesToExamCalendarParams({
    required this.tenantId,
    required this.examCalendarId,
    required this.gradeSectionIds,
  });

  @override
  List<Object> get props => [tenantId, examCalendarId, gradeSectionIds];
}
