// domain/usecases/get_exam_types.dart
import '../entities/exam_type_entity.dart';
import '../repositories/qps_repository.dart';

class GetExamTypes {
  final QpsRepository repository;
  GetExamTypes(this.repository);

  Future<List<ExamTypeEntity>> call() async {
    return await repository.getExamTypes();
  }
}
