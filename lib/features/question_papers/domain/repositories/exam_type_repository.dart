// features/question_papers/domain/repositories/exam_type_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_type_entity.dart';

abstract class ExamTypeRepository {
  /// Get all exam types for the current tenant
  Future<Either<Failure, List<ExamTypeEntity>>> getExamTypes();

  /// Get a specific exam type by ID
  Future<Either<Failure, ExamTypeEntity?>> getExamTypeById(String id);

  /// Create a new exam type (admin only)
  Future<Either<Failure, ExamTypeEntity>> createExamType(ExamTypeEntity examType);

  /// Update an existing exam type (admin only)
  Future<Either<Failure, ExamTypeEntity>> updateExamType(ExamTypeEntity examType);

  /// Delete an exam type (admin only)
  Future<Either<Failure, void>> deleteExamType(String id);
}