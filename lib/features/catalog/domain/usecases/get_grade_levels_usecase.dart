// features/catalog/domain/usecases/get_grade_levels_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/grade_repository.dart';

class GetGradeLevelsUseCase {
  final GradeRepository repository;

  GetGradeLevelsUseCase(this.repository);

  Future<Either<Failure, List<int>>> call() async {
    return await repository.getAvailableGradeLevels();
  }
}