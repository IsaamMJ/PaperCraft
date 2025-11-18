import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/repositories/question_paper_repository.dart';

class RestoreSparePaperUseCase {
  final QuestionPaperRepository repository;
  final ILogger logger;

  RestoreSparePaperUseCase(
    this.repository,
    this.logger,
  );

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    final result = await repository.restoreSparePaper(paperId);

    return result.fold(
      (failure) => Left(failure),
      (paper) {
        logger.info('Spare paper restored to submitted', category: LogCategory.paper, context: {
          'paperId': paper.id,
          'title': paper.title,
        });
        return Right(paper);
      },
    );
  }
}
