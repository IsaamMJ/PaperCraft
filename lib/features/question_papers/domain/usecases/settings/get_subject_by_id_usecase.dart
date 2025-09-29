import 'package:dartz/dartz.dart';

import '../../../../../core/domain/errors/failures.dart';
import '../../entities/subject_entity.dart';
import '../../repositories/subject_repository.dart';

class GetSubjectByIdUseCase {
  final SubjectRepository _repository;

  GetSubjectByIdUseCase(this._repository);

  Future<Either<Failure, SubjectEntity?>> call(String id) async {
    return await _repository.getSubjectById(id);
  }
}