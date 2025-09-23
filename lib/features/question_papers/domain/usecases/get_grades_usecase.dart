import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/grade_entity.dart';
import '../repositories/grade_repository.dart';

class GetGradesUseCase {
  final GradeRepository repository;

  GetGradesUseCase(this.repository);

  Future<Either<Failure, List<GradeEntity>>> call() async {
    return await repository.getGrades();
  }
}

class GetGradeLevelsUseCase {
  final GradeRepository repository;

  GetGradeLevelsUseCase(this.repository);

  Future<Either<Failure, List<int>>> call() async {
    return await repository.getAvailableGradeLevels();
  }
}

class GetSectionsByGradeUseCase {
  final GradeRepository repository;

  GetSectionsByGradeUseCase(this.repository);

  Future<Either<Failure, List<String>>> call(int gradeLevel) async {
    return await repository.getSectionsByGradeLevel(gradeLevel);
  }
}