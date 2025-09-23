import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class GetPapersForReviewUseCase {
  final QuestionPaperRepository repository;

  GetPapersForReviewUseCase(this.repository);

  Future<Either<Failure, List<QuestionPaperEntity>>> call() async {
    return await repository.getPapersForReview();
  }
}
