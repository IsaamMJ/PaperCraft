import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/student_mark_entry_dto.dart';
import '../repositories/student_exam_marks_repository.dart';

class SaveMarksAsDraftUsecase {
  final StudentExamMarksRepository _repository;

  SaveMarksAsDraftUsecase({required StudentExamMarksRepository repository})
      : _repository = repository;

  /// Save marks as draft without finalizing
  /// Allows teachers to save their progress and come back later
  /// Returns the count of updated records
  Future<Either<Failure, MarksSubmissionResponse>> call({
    required BulkMarksEntryRequest request,
  }) async {
    return await _repository.saveMarksAsDraft(request);
  }
}
