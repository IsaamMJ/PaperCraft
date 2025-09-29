import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/grade_entity.dart';

abstract class GradeRepository {
  Future<Either<Failure, List<GradeEntity>>> getGrades();
  Future<Either<Failure, List<GradeEntity>>> getGradesByLevel(int level);
  Future<Either<Failure, List<int>>> getAvailableGradeLevels();
  Future<Either<Failure, List<String>>> getSectionsByGradeLevel(int level);

  // NEW CRUD METHODS
  Future<Either<Failure, GradeEntity>> createGrade(GradeEntity grade);
  Future<Either<Failure, GradeEntity>> updateGrade(GradeEntity grade);
  Future<Either<Failure, void>> deleteGrade(String id);
}