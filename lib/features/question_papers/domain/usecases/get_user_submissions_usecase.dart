import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class GetUserSubmissionsUseCase {
  final QuestionPaperRepository repository;

  GetUserSubmissionsUseCase(this.repository);

  Future<Either<Failure, List<QuestionPaperEntity>>> call() async {
    return await repository.getUserSubmissions();
  }
}