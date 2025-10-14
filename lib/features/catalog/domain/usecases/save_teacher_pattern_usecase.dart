// features/catalog/domain/usecases/save_teacher_pattern_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_pattern_entity.dart';
import '../repositories/teacher_pattern_repository.dart';

/// Use case for saving or updating teacher patterns
/// Handles smart de-duplication logic
class SaveTeacherPatternUseCase {
  final ITeacherPatternRepository repository;

  SaveTeacherPatternUseCase(this.repository);

  /// Save or update a pattern
  /// If identical pattern exists, increments use count
  /// Otherwise creates new pattern
  Future<Either<Failure, TeacherPatternEntity>> call({
    required TeacherPatternEntity pattern,
  }) async {
    try {
      // Validate pattern before saving
      final validationError = _validatePattern(pattern);
      if (validationError != null) {
        return Left(ValidationFailure(validationError));
      }

      final savedPattern = await repository.saveOrUpdatePattern(
        pattern: pattern,
      );
      return Right(savedPattern);
    } catch (e) {
      return Left(ServerFailure('Failed to save pattern: ${e.toString()}'));
    }
  }

  /// Validate pattern before saving
  String? _validatePattern(TeacherPatternEntity pattern) {
    if (pattern.name.trim().isEmpty) {
      return 'Pattern name cannot be empty';
    }

    if (pattern.sections.isEmpty) {
      return 'Pattern must have at least one section';
    }

    if (pattern.totalQuestions <= 0) {
      return 'Pattern must have at least one question';
    }

    if (pattern.totalMarks <= 0) {
      return 'Pattern total marks must be greater than zero';
    }

    // Validate each section
    for (var section in pattern.sections) {
      if (section.name.trim().isEmpty) {
        return 'All sections must have a name';
      }
      if (section.questions <= 0) {
        return 'Section "${section.name}" must have at least one question';
      }
      if (section.marksPerQuestion <= 0) {
        return 'Section "${section.name}" must have marks per question greater than zero';
      }
    }

    return null;
  }
}
