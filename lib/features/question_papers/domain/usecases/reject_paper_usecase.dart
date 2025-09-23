import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class RejectPaperUseCase {
  final QuestionPaperRepository repository;

  RejectPaperUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId, String reason) async {
    if (reason.trim().isEmpty) {
      return Left(ValidationFailure('Rejection reason is required'));
    }

    return await repository.rejectPaper(paperId, reason.trim());
  }
}