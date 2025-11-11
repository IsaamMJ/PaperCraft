import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class UpdatePaperUseCase {
  final QuestionPaperRepository repository;

  UpdatePaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    if (paper.title.trim().isEmpty) {
      return Left(ValidationFailure('Title is required'));
    }

    if (paper.questions.isEmpty) {
      return Left(ValidationFailure('At least one question is required'));
    }

    return await repository.updatePaper(paper);
  }
}
