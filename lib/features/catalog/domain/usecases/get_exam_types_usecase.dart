// features/question_papers/domain/usecases/get_exam_types_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_type_entity.dart';
import '../repositories/exam_type_repository.dart';

class GetExamTypesUseCase {
  final ExamTypeRepository repository;

  GetExamTypesUseCase(this.repository);

  Future<Either<Failure, List<ExamTypeEntity>>> call() async {
    return await repository.getExamTypes();
  }
}

class GetExamTypeByIdUseCase {
  final ExamTypeRepository repository;

  GetExamTypeByIdUseCase(this.repository);

  Future<Either<Failure, ExamTypeEntity?>> call(String id) async {
    if (id.trim().isEmpty) {
      return Left(ValidationFailure('Exam type ID is required'));
    }
    return await repository.getExamTypeById(id.trim());
  }
}