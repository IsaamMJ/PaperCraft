// domain/usecases/get_subjects.dart
import '../entities/subject_entity.dart';
import '../repositories/qps_repository.dart';

class GetSubjects {
  final QpsRepository repository;
  GetSubjects(this.repository);

  Future<List<SubjectEntity>> call() async {
    return await repository.getSubjects();
  }
}
