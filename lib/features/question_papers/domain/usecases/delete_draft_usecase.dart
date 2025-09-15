import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/question_paper_repository.dart';

class DeleteDraftUseCase {
  final QuestionPaperRepository repository;

  DeleteDraftUseCase(this.repository);

  Future<Either<Failure, void>> call(String draftId) async {
    return await repository.deleteDraft(draftId);
  }
}
