import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_calendar.dart';
import '../repositories/exam_calendar_repository.dart';

/// Use case: Load all exams in the calendar for a tenant
///
/// Called by: ExamCalendarListPage (admin UI to view calendar)
class LoadExamCalendarsUseCase {
  final ExamCalendarRepository repository;

  LoadExamCalendarsUseCase({required this.repository});

  Future<Either<Failure, List<ExamCalendar>>> call({
    required String tenantId,
    String? academicYear,
  }) async {
    return await repository.getExamCalendars(
      tenantId: tenantId,
      academicYear: academicYear,
      activeOnly: true,
      sortByMonth: true,
    );
  }
}
