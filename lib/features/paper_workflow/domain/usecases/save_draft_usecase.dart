// features/paper_workflow/domain/usecases/save_draft_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class SaveDraftUseCase {
  final QuestionPaperRepository repository;

  SaveDraftUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    // Validation
    if (paper.title.trim().isEmpty) {
      return Left(ValidationFailure('Title is required'));
    }

    if (paper.questions.isEmpty) {
      return Left(ValidationFailure('At least one question is required'));
    }

    if (paper.subjectId.isEmpty) {
      return Left(ValidationFailure('Subject is required'));
    }

    if (paper.gradeId.isEmpty) {
      return Left(ValidationFailure('Grade is required'));
    }

    if (paper.paperSections.isEmpty) {
      return Left(ValidationFailure('Paper sections are required'));
    }

    return await repository.saveDraft(paper);
  }
}