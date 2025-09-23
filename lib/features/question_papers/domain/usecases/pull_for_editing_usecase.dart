import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class PullForEditingUseCase {
  final QuestionPaperRepository repository;

  PullForEditingUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    return await repository.pullForEditing(paperId);
  }
}