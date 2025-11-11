import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entry_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for adding a new exam entry to a timetable
class AddExamEntryUsecase {
  final ExamTimetableRepository _repository;

  AddExamEntryUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  Future<Either<Failure, ExamTimetableEntryEntity>> call({
    required AddExamEntryParams params,
  }) async {
    try {

      final result = await _repository.addExamTimetableEntry(params.entry);

      return result.fold(
        (failure) {
          return Left(failure);
        },
        (entry) {
          return Right(entry);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Failed to add exam entry: $e'));
    }
  }
}

class AddExamEntryParams {
  final ExamTimetableEntryEntity entry;

  AddExamEntryParams({required this.entry});
}
