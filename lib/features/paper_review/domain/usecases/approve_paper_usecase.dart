import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/repositories/question_paper_repository.dart';

class ApprovePaperUseCase {
  final QuestionPaperRepository repository;

  ApprovePaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    return await repository.approvePaper(paperId);
  }
}