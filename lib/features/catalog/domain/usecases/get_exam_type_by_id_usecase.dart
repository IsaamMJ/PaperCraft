import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_type_entity.dart';
import '../repositories/exam_type_repository.dart';
class GetExamTypeByIdUseCase {
  final ExamTypeRepository _repository;

  GetExamTypeByIdUseCase(this._repository);

  Future<Either<Failure, ExamTypeEntity?>> call(String id) async {
    return await _repository.getExamTypeById(id);
  }
}