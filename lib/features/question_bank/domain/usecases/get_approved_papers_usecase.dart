import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/repositories/question_paper_repository.dart';

class GetApprovedPapersUseCase {
  final QuestionPaperRepository repository;

  GetApprovedPapersUseCase(this.repository);

  Future<Either<Failure, List<QuestionPaperEntity>>> call() async {
    return await repository.getApprovedPapers();
  }
}