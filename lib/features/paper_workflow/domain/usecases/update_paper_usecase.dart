import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/usecases/usecase.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class UpdatePaperUseCase extends UseCase<QuestionPaperEntity, QuestionPaperEntity> {
  final QuestionPaperRepository _repository;

  UpdatePaperUseCase(this._repository);

  @override
  Future<Either<Failure, QuestionPaperEntity>> call(QuestionPaperEntity paper) async {
    return await _repository.updatePaper(paper);
  }
}
