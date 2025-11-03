import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_calendar_repository.dart';

/// Use case: Delete (soft delete) an exam from the calendar
///
/// Called by: ExamCalendarListPage (admin removes exam)
///
/// Note: Uses soft delete (is_active = false) to preserve historical data
/// Timetables created from this calendar remain valid
class DeleteExamCalendarUseCase {
  final ExamCalendarRepository repository;

  DeleteExamCalendarUseCase({required this.repository});

  Future<Either<Failure, void>> call({required String calendarId}) async {
    return await repository.deleteExamCalendar(calendarId);
  }
}
