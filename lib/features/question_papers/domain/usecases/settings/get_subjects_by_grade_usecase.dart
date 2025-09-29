import 'package:dartz/dartz.dart';
import '../../../../../core/domain/errors/failures.dart';
import '../../entities/subject_entity.dart';
import '../../repositories/subject_repository.dart';

class GetSubjectsByGradeUseCase {
  final SubjectRepository _repository;

  GetSubjectsByGradeUseCase(this._repository);

  Future<Either<Failure, List<SubjectEntity>>> call(int gradeLevel) async {
    return await _repository.getSubjectsByGrade(gradeLevel);
  }
}