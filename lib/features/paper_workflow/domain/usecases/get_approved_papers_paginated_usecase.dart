// features/paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/models/paginated_result.dart';
import '../entities/question_paper_entity.dart';
import '../repositories/question_paper_repository.dart';

class GetApprovedPapersPaginatedUseCase {
  final QuestionPaperRepository _repository;

  GetApprovedPapersPaginatedUseCase(this._repository);

  /// Get paginated approved papers with optional filters
  Future<Either<Failure, PaginatedResult<QuestionPaperEntity>>> call({
    required int page,
    int pageSize = 20,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
  }) async {
    if (page < 1) {
      return Left(ValidationFailure('Page number must be greater than 0'));
    }

    if (pageSize < 1 || pageSize > 100) {
      return Left(ValidationFailure('Page size must be between 1 and 100'));
    }

    return await _repository.getApprovedPapersPaginated(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      subjectFilter: subjectFilter,
      gradeFilter: gradeFilter,
    );
  }
}
