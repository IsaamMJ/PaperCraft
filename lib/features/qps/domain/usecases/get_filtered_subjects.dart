import '../entities/subject_entity.dart';
import '../repositories/qps_repository.dart';

class GetFilteredSubjects {
  final QpsRepository repository;
  GetFilteredSubjects(this.repository);

  Future<List<SubjectEntity>> call() async {
    return await repository.getFilteredSubjects();
  }
}