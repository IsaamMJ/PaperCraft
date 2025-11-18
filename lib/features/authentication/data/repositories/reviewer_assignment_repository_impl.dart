import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../domain/entities/reviewer_assignment_entity.dart';
import '../../domain/repositories/reviewer_assignment_repository.dart';
import '../datasources/reviewer_assignment_data_source.dart';

class ReviewerAssignmentRepositoryImpl implements ReviewerAssignmentRepository {
  final ReviewerAssignmentDataSource _dataSource;
  final ILogger _logger;

  ReviewerAssignmentRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<Either<Failure, List<ReviewerAssignmentEntity>>> getReviewerAssignments(
    String tenantId,
  ) async {
    try {
      print('[DEBUG REPO] Getting reviewer assignments for tenant: $tenantId');
      final assignments = await _dataSource.getReviewerAssignments(tenantId);
      print('[DEBUG REPO] Got ${assignments.length} assignments from DS');
      return Right(assignments.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      print('[DEBUG REPO] Error getting assignments: $e');
      _logger.error('Failed to get reviewer assignments',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to load assignments: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ReviewerAssignmentEntity>> getReviewerAssignment(
    String assignmentId,
  ) async {
    try {
      final assignment = await _dataSource.getReviewerAssignment(assignmentId);
      return Right(assignment.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to get reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to load assignment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ReviewerAssignmentEntity>> createReviewerAssignment({
    required String tenantId,
    required String reviewerId,
    required int gradeMin,
    required int gradeMax,
  }) async {
    try {
      print('[DEBUG REPO] Creating assignment: reviewerId=$reviewerId, grades=$gradeMin-$gradeMax');
      final assignment = await _dataSource.createReviewerAssignment(
        tenantId: tenantId,
        reviewerId: reviewerId,
        gradeMin: gradeMin,
        gradeMax: gradeMax,
      );
      print('[DEBUG REPO] Assignment created: ${assignment.id}');
      return Right(assignment.toEntity());
    } catch (e, stackTrace) {
      print('[DEBUG REPO] Error creating assignment: $e');
      _logger.error('Failed to create reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to create assignment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ReviewerAssignmentEntity>> updateReviewerAssignment({
    required String assignmentId,
    required int gradeMin,
    required int gradeMax,
  }) async {
    try {
      print('[DEBUG REPO] Updating assignment: assignmentId=$assignmentId, grades=$gradeMin-$gradeMax');
      final assignment = await _dataSource.updateReviewerAssignment(
        assignmentId: assignmentId,
        gradeMin: gradeMin,
        gradeMax: gradeMax,
      );
      print('[DEBUG REPO] Assignment updated successfully');
      return Right(assignment.toEntity());
    } catch (e, stackTrace) {
      print('[DEBUG REPO] Error updating assignment: $e');
      _logger.error('Failed to update reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update assignment: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReviewerAssignment(String assignmentId) async {
    try {
      print('[DEBUG REPO] Deleting assignment: assignmentId=$assignmentId');
      await _dataSource.deleteReviewerAssignment(assignmentId);
      print('[DEBUG REPO] Assignment deleted successfully');
      return const Right(null);
    } catch (e, stackTrace) {
      print('[DEBUG REPO] Error deleting assignment: $e');
      _logger.error('Failed to delete reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete assignment: ${e.toString()}'));
    }
  }
}
