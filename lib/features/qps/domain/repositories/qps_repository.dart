// domain/repositories/qps_repository.dart
import '../entities/exam_type_entity.dart';
import '../entities/subject_entity.dart';
import '../entities/grade_entity.dart';
import '../entities/user_permissions_entity.dart';

abstract class QpsRepository {
  /// Fetches all exam types for the logged-in tenant
  Future<List<ExamTypeEntity>> getExamTypes();

  /// Fetches all subjects for the logged-in tenant
  Future<List<SubjectEntity>> getSubjects();

  /// Fetches all grades for the logged-in tenant
  Future<List<GradeEntity>> getGrades();

  /// Fetches user permissions for the current user
  Future<UserPermissionsEntity?> getUserPermissions();

  /// Fetches filtered subjects based on user permissions
  Future<List<SubjectEntity>> getFilteredSubjects();

  /// Fetches filtered grades based on user permissions
  Future<List<GradeEntity>> getFilteredGrades();

  /// Check if user can create papers for specific subject and grade
  Future<bool> canCreatePaper(String subjectId, int gradeLevel);
}