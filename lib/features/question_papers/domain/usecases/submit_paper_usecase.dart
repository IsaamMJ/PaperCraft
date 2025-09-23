// features/question_papers/domain2/usecases/submit_paper_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class SubmitPaperUseCase {
  final QuestionPaperRepository repository;

  SubmitPaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    // Validate paper can be submitted
    if (!paper.canSubmit) {
      return Left(ValidationFailure(_getSubmissionError(paper)));
    }

    // Validate all questions are valid
    if (!paper.hasValidQuestions) {
      return Left(ValidationFailure('Paper contains invalid questions: ${paper.validationErrors.join(', ')}'));
    }

    return await repository.submitPaper(paper);
  }

  String _getSubmissionError(QuestionPaperEntity paper) {
    if (!paper.status.isDraft) {
      return 'Only drafts can be submitted. Current status: ${paper.status.displayName}';
    }

    if (paper.questions.isEmpty) {
      return 'Paper must have questions';
    }

    if (paper.title.trim().isEmpty) {
      return 'Paper must have a title';
    }

    if (!paper.isComplete) {
      return 'Paper is incomplete: ${paper.validationErrors.join(', ')}';
    }

    return 'Paper cannot be submitted';
  }
}