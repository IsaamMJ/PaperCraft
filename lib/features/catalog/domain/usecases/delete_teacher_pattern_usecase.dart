// features/catalog/domain/usecases/delete_teacher_pattern_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/teacher_pattern_repository.dart';

/// Use case for deleting teacher patterns
class DeleteTeacherPatternUseCase {
  final ITeacherPatternRepository repository;

  DeleteTeacherPatternUseCase(this.repository);

  /// Delete a pattern by ID
  Future<Either<Failure, void>> call({
    required String patternId,
  }) async {
    try {
      if (patternId.trim().isEmpty) {
        return Left(ValidationFailure('Pattern ID cannot be empty'));
      }

      await repository.deletePattern(patternId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete pattern: ${e.toString()}'));
    }
  }
}
