import '../entities/grade_entity.dart';
import '../repositories/qps_repository.dart';

class GetGrades {
  final QpsRepository repository;
  GetGrades(this.repository);

  Future<List<GradeEntity>> call() async {
    return await repository.getGrades();
  }
}