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
      print('[AddExamEntry] Adding entry: ${params.entry.subjectId} for Grade ${params.entry.gradeId}-${params.entry.section}');

      final result = await _repository.addExamTimetableEntry(params.entry);

      return result.fold(
        (failure) {
          print('[AddExamEntry] Failed to add entry: ${failure.message}');
          return Left(failure);
        },
        (entry) {
          print('[AddExamEntry] Entry added successfully: ${entry.id}');
          return Right(entry);
        },
      );
    } catch (e) {
      print('[AddExamEntry] ERROR: $e');
      return Left(ServerFailure('Failed to add exam entry: $e'));
    }
  }
}

class AddExamEntryParams {
  final ExamTimetableEntryEntity entry;

  AddExamEntryParams({required this.entry});
}
