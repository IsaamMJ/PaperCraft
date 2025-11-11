import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for Step 2: Get all grade sections mapped to an exam calendar
///
/// Retrieves the list of grade section IDs that are currently associated with
/// a specific exam calendar. Used to show which grade sections are already selected
/// when user re-visits Step 2.
///
/// Example:
/// ```dart
/// final result = await getGradesForCalendar('calendar-456');
/// // Returns: ['section-1', 'section-2', 'section-3']
/// ```
class GetGradesForCalendarUsecase {
  final ExamTimetableRepository repository;

  GetGradesForCalendarUsecase({
    required this.repository,
  });

  Future<Either<Failure, List<String>>> call(
    GetGradesForCalendarParams params,
  ) async {
    if (params.examCalendarId.isEmpty) {
      return Left(ValidationFailure('Exam calendar ID cannot be empty'));
    }

    return await repository.getGradesForCalendar(params.examCalendarId);
  }
}

/// Parameters for GetGradesForCalendarUsecase
class GetGradesForCalendarParams extends Equatable {
  final String examCalendarId;

  const GetGradesForCalendarParams({
    required this.examCalendarId,
  });

  @override
  List<Object> get props => [examCalendarId];
}
