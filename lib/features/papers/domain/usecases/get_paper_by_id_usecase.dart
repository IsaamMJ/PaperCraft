
// features/question_papers/domain2/usecases/get_paper_by_id_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class GetPaperByIdUseCase {
  final QuestionPaperRepository repository;

  GetPaperByIdUseCase(this.repository);

  Future<Either<Failure, QuestionPaperEntity?>> call(String paperId) async {
    if (paperId.trim().isEmpty) {
      return Left(ValidationFailure('Paper ID is required'));
    }

    return await repository.getPaperById(paperId.trim());
  }
}