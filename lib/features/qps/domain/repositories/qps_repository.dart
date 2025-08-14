// domain/repositories/qps_repository.dart

import '../entities/exam_type_entity.dart';
import '../entities/subject_entity.dart';

abstract class QpsRepository {
  /// Fetches all exam types for the logged-in tenant
  Future<List<ExamTypeEntity>> getExamTypes();

  /// Fetches all subjects for the logged-in tenant
  Future<List<SubjectEntity>> getSubjects();
}
