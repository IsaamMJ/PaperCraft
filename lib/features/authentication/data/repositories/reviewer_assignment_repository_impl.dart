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
      final assignments = await _dataSource.getReviewerAssignments(tenantId);
      return Right(assignments.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
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
      final assignment = await _dataSource.createReviewerAssignment(
        tenantId: tenantId,
        reviewerId: reviewerId,
        gradeMin: gradeMin,
        gradeMax: gradeMax,
      );
      return Right(assignment.toEntity());
    } catch (e, stackTrace) {
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
      final assignment = await _dataSource.updateReviewerAssignment(
        assignmentId: assignmentId,
        gradeMin: gradeMin,
        gradeMax: gradeMax,
      );
      return Right(assignment.toEntity());
    } catch (e, stackTrace) {
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
      await _dataSource.deleteReviewerAssignment(assignmentId);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      return Left(ServerFailure('Failed to delete assignment: ${e.toString()}'));
    }
  }
}
