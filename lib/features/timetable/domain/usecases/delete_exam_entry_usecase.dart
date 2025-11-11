import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for deleting an exam entry from a timetable
class DeleteExamEntryUsecase {
  final ExamTimetableRepository _repository;

  DeleteExamEntryUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  Future<Either<Failure, void>> call({
    required DeleteExamEntryParams params,
  }) async {
    try {
      
      final result = await _repository.deleteExamTimetableEntry(params.entryId);
      
      return result.fold(
        (failure) {
          return Left(failure);
        },
        (_) {
          return const Right(null);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Failed to delete exam entry: $e'));
    }
  }
}

class DeleteExamEntryParams {
  final String entryId;

  DeleteExamEntryParams({required this.entryId});
}
