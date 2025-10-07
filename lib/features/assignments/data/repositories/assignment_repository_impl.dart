// features/assignments/data/repositories/assignment_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/data/datasources/grade_data_source.dart';
import '../../../catalog/data/datasources/subject_data_source.dart';
import '../../domain/repositories/assignment_repository.dart';
import '../datasources/assignment_data_source.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  final AssignmentDataSource _assignmentDataSource;
  final GradeDataSource _gradeDataSource;
  final SubjectDataSource _subjectDataSource;
  final ILogger _logger;

  AssignmentRepositoryImpl(
      this._assignmentDataSource,
      this._gradeDataSource,
      this._subjectDataSource,
      this._logger,
      );

  Future<String?> _getTenantId() async => sl<UserStateService>().currentTenantId;

  @override
  Future<Either<Failure, List<GradeEntity>>> getTeacherAssignedGrades(
      String teacherId,
      String academicYear,
      ) async {
    try {
      final tenantId = await _getTenantId();
      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      // Get grade assignments
      final assignments = await _assignmentDataSource.getTeacherGradeAssignments(
        teacherId,
        academicYear,
      );

      // Get all grades for the tenant
      final allGrades = await _gradeDataSource.getGrades(tenantId);

      // Filter grades that are assigned
      final assignedGradeIds = assignments.map((a) => a.gradeId).toSet();
      final assignedGrades = allGrades
          .where((g) => assignedGradeIds.contains(g.id))
          .map((g) => g.toEntity())
          .toList();

      return Right(assignedGrades);
    } catch (e, stackTrace) {
      _logger.error('Failed to get teacher assigned grades',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get assigned grades: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SubjectEntity>>> getTeacherAssignedSubjects(
      String teacherId,
      String academicYear,
      ) async {
    try {
      final tenantId = await _getTenantId();
      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      // Get subject assignments
      final assignments = await _assignmentDataSource.getTeacherSubjectAssignments(
        teacherId,
        academicYear,
      );

      // Get all subjects for the tenant
      final allSubjects = await _subjectDataSource.getSubjects(tenantId);

      // Filter subjects that are assigned
      final assignedSubjectIds = assignments.map((a) => a.subjectId).toSet();
      final assignedSubjects = allSubjects
          .where((s) => assignedSubjectIds.contains(s.id))
          .map((s) => s.toEntity())
          .toList();

      return Right(assignedSubjects);
    } catch (e, stackTrace) {
      _logger.error('Failed to get teacher assigned subjects',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get assigned subjects: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> assignGradeToTeacher({
    required String teacherId,
    required String gradeId,
    required String academicYear,
  }) async {
    try {
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      await _assignmentDataSource.assignGradeToTeacher(
        tenantId: tenantId,
        teacherId: teacherId,
        gradeId: gradeId,
        academicYear: academicYear,
      );

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to assign grade to teacher',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to assign grade: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> assignSubjectToTeacher({
    required String teacherId,
    required String subjectId,
    required String academicYear,
  }) async {
    try {
      final tenantId = await _getTenantId();
      final userStateService = sl<UserStateService>();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      await _assignmentDataSource.assignSubjectToTeacher(
        tenantId: tenantId,
        teacherId: teacherId,
        subjectId: subjectId,
        academicYear: academicYear,
      );

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to assign subject to teacher',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to assign subject: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> removeGradeAssignment({
    required String teacherId,
    required String gradeId,
    required String academicYear,
  }) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      // Get the assignment to find its ID
      final assignments = await _assignmentDataSource.getTeacherGradeAssignments(
        teacherId,
        academicYear,
      );

      final assignment = assignments.firstWhere(
            (a) => a.gradeId == gradeId,
        orElse: () => throw Exception('Assignment not found'),
      );

      await _assignmentDataSource.removeGradeAssignment(assignment.id);

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to remove grade assignment',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to remove grade assignment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> removeSubjectAssignment({
    required String teacherId,
    required String subjectId,
    required String academicYear,
  }) async {
    try {
      final userStateService = sl<UserStateService>();

      if (!userStateService.canManageUsers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      // Get the assignment to find its ID
      final assignments = await _assignmentDataSource.getTeacherSubjectAssignments(
        teacherId,
        academicYear,
      );

      final assignment = assignments.firstWhere(
            (a) => a.subjectId == subjectId,
        orElse: () => throw Exception('Assignment not found'),
      );

      await _assignmentDataSource.removeSubjectAssignment(assignment.id);

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to remove subject assignment',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to remove subject assignment: ${e.toString()}'));
    }
  }
}