import '../repositories/qps_repository.dart';

class CanCreatePaper {
  final QpsRepository repository;
  CanCreatePaper(this.repository);

  Future<bool> call(String subjectId, int gradeLevel) async {
    return await repository.canCreatePaper(subjectId, gradeLevel);
  }
}