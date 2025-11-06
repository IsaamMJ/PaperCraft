import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';
import '../../domain/repositories/teacher_assignment_repository.dart';
import '../datasources/teacher_assignment_datasource.dart';

/// Implementation of TeacherAssignmentRepository using Supabase
///
/// Provides data access layer for teacher assignment management
/// Wraps datasource calls with error handling and failure mapping
class TeacherAssignmentRepositoryImpl implements TeacherAssignmentRepository {
  final TeacherAssignmentDataSource dataSource;

  TeacherAssignmentRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<TeacherSubjectAssignmentEntity>>>
      getTeacherAssignments({
    required String tenantId,
    String? teacherId,
    String academicYear = '2025-2026',
    bool activeOnly = true,
  }) async {
    try {
      final assignments = await dataSource.getTeacherAssignments(
        tenantId: tenantId,
        teacherId: teacherId,
        academicYear: academicYear,
        activeOnly: activeOnly,
      );

      return Right(assignments);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to fetch teacher assignments: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getAssignmentStats({
    required String tenantId,
    String academicYear = '2025-2026',
  }) async {
    try {
      final stats = await dataSource.getAssignmentStats(
        tenantId: tenantId,
        academicYear: academicYear,
      );

      return Right(stats);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to fetch assignment stats: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> saveAssignment(
    TeacherSubjectAssignmentEntity assignment,
  ) async {
    try {
      // Validate assignment has required display fields
      if (!assignment.isValid) {
        return Left(
          ValidationFailure(
            'Assignment must have grade, section, and subject',
          ),
        );
      }

      await dataSource.saveAssignment(assignment);

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to save assignment: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteAssignment(String assignmentId) async {
    try {
      await dataSource.deleteAssignment(assignmentId);

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to delete assignment: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TeacherSubjectAssignmentEntity?>> getAssignmentById(
    String id,
  ) async {
    try {
      final assignment = await dataSource.getAssignmentById(id);

      return Right(assignment);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to fetch assignment: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TeacherSubjectAssignmentEntity>>>
      getAssignmentsForTeacher({
    required String tenantId,
    required String teacherId,
    String academicYear = '2025-2026',
  }) async {
    try {
      final assignments = await dataSource.getAssignmentsForTeacher(
        tenantId: tenantId,
        teacherId: teacherId,
        academicYear: academicYear,
      );

      return Right(assignments);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          'Failed to fetch teacher assignments: ${e.toString()}',
        ),
      );
    }
  }
}
