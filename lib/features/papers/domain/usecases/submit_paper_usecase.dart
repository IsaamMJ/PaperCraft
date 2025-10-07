// features/papers/domain/usecases/submit_paper_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class SubmitPaperUseCase {
  final QuestionPaperRepository repository;

  SubmitPaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    // Validation
    if (!paper.canSubmit) {
      return Left(ValidationFailure(
        'Paper cannot be submitted: ${paper.validationErrors.join(", ")}',
      ));
    }

    return await repository.submitPaper(paper);
  }
}