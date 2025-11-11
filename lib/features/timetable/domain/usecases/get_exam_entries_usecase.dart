import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable_entry_entity.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case for fetching all exam entries for a timetable
class GetExamEntriesUsecase {
  final ExamTimetableRepository _repository;

  GetExamEntriesUsecase({required ExamTimetableRepository repository})
      : _repository = repository;

  Future<Either<Failure, ExamEntriesData>> call({
    required GetExamEntriesParams params,
  }) async {
    try {
      
      final result = await _repository.getExamTimetableEntries(params.timetableId);
      
      return result.fold(
        (failure) {
          return Left(failure);
        },
        (entries) {
          final data = ExamEntriesData(
            entries: entries,
            totalCount: entries.length,
            lastUpdated: DateTime.now(),
          );
          return Right(data);
        },
      );
    } catch (e) {
      return Left(ServerFailure('Failed to fetch exam entries: $e'));
    }
  }
}

class GetExamEntriesParams {
  final String timetableId;

  GetExamEntriesParams({required this.timetableId});
}
