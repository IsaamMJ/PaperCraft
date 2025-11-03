import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case: Delete (soft delete) an exam timetable
///
/// Called by: ExamTimetableListPage (admin deletes timetable)
///
/// Note: Can only delete timetables in draft status
/// Published timetables are archived instead
class DeleteExamTimetableUseCase {
  final ExamTimetableRepository repository;

  DeleteExamTimetableUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required String timetableId,
  }) async {
    return await repository.deleteTimetable(timetableId);
  }
}
