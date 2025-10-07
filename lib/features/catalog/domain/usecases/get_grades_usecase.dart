// features/question_papers/domain/usecases/get_grades_usecase.dart
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