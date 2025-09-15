import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class ApprovePaperUseCase {
  final QuestionPaperRepository repository;

  ApprovePaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    return await repository.approvePaper(paperId);
  }
}