import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/admin_setup_repository.dart';

/// Use case to get subject suggestions for a grade
class GetSubjectSuggestionsUseCase {
  final AdminSetupRepository repository;

  GetSubjectSuggestionsUseCase({required this.repository});

  /// Get subject suggestions for a specific grade
  Future<Either<Failure, List<String>>> call({required int gradeNumber}) {
    return repository.getSubjectSuggestions(gradeNumber);
  }
}
