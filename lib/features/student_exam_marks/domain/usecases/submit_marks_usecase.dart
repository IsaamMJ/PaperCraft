import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/student_mark_entry_dto.dart';
import '../repositories/student_exam_marks_repository.dart';

class SubmitMarksUsecase {
  final StudentExamMarksRepository _repository;

  SubmitMarksUsecase({required StudentExamMarksRepository repository})
      : _repository = repository;

  /// Submit marks - finalizes the marks entry for this exam
  /// Once submitted, marks cannot be edited (is_draft = false)
  /// Returns the count of updated records
  Future<Either<Failure, MarksSubmissionResponse>> call({
    required BulkMarksEntryRequest request,
  }) async {
    return await _repository.submitMarks(request);
  }
}
