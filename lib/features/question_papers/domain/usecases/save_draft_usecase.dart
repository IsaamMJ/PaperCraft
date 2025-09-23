import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class SaveDraftUseCase {
  final QuestionPaperRepository repository;

  SaveDraftUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    return await repository.saveDraft(paper);
  }
}
