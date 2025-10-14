// features/catalog/domain/usecases/get_teacher_patterns_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_pattern_entity.dart';
import '../repositories/teacher_pattern_repository.dart';

/// Use case for retrieving teacher patterns
class GetTeacherPatternsUseCase {
  final ITeacherPatternRepository repository;

  GetTeacherPatternsUseCase(this.repository);

  /// Get patterns for a specific teacher and subject
  Future<Either<Failure, List<TeacherPatternEntity>>> call({
    required String teacherId,
    required String subjectId,
  }) async {
    try {
      final patterns = await repository.getPatternsByTeacherAndSubject(
        teacherId: teacherId,
        subjectId: subjectId,
      );
      return Right(patterns);
    } catch (e) {
      return Left(ServerFailure('Failed to load patterns: ${e.toString()}'));
    }
  }

  /// Get all patterns for a teacher (across all subjects)
  Future<Either<Failure, List<TeacherPatternEntity>>> getAllPatterns({
    required String teacherId,
  }) async {
    try {
      final patterns = await repository.getPatternsByTeacher(
        teacherId: teacherId,
      );
      return Right(patterns);
    } catch (e) {
      return Left(ServerFailure('Failed to load patterns: ${e.toString()}'));
    }
  }

  /// Get most frequently used patterns
  Future<Either<Failure, List<TeacherPatternEntity>>> getMostUsed({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  }) async {
    try {
      final patterns = await repository.getMostUsedPatterns(
        teacherId: teacherId,
        subjectId: subjectId,
        limit: limit,
      );
      return Right(patterns);
    } catch (e) {
      return Left(ServerFailure('Failed to load frequently used patterns: ${e.toString()}'));
    }
  }

  /// Get recently used patterns
  Future<Either<Failure, List<TeacherPatternEntity>>> getRecent({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  }) async {
    try {
      final patterns = await repository.getRecentPatterns(
        teacherId: teacherId,
        subjectId: subjectId,
        limit: limit,
      );
      return Right(patterns);
    } catch (e) {
      return Left(ServerFailure('Failed to load recent patterns: ${e.toString()}'));
    }
  }
}
