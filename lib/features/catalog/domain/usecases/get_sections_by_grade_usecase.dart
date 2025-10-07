// features/catalog/domain/usecases/get_sections_by_grade_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/grade_repository.dart';

class GetSectionsByGradeUseCase {
  final GradeRepository repository;

  GetSectionsByGradeUseCase(this.repository);

  Future<Either<Failure, List<String>>> call(int gradeLevel) async {
    return await repository.getSectionsByGradeLevel(gradeLevel);
  }
}