import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class GetApprovedPapersByExamDateRangeUseCase {
  final QuestionPaperRepository _repository;

  GetApprovedPapersByExamDateRangeUseCase(this._repository);

  Future<Either<Failure, List<QuestionPaperEntity>>> call({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    return await _repository.getApprovedPapersByExamDateRange(
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
