import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class SearchPapersUseCase {
  final QuestionPaperRepository repository;

  SearchPapersUseCase(this.repository);

  Future<Either<Failure, List<QuestionPaperEntity>>> call({
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  }) async {
    return await repository.searchPapers(
      title: title,
      subject: subject,
      status: status,
      createdBy: createdBy,
    );
  }
}
