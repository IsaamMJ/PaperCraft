// features/paper_workflow/domain/usecases/pull_for_editing_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class PullForEditingUseCase {
  final QuestionPaperRepository repository;

  PullForEditingUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    if (paperId.trim().isEmpty) {
      return Left(ValidationFailure('Paper ID is required'));
    }

    return await repository.pullForEditing(paperId.trim());
  }
}