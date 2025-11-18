import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/reviewer_assignment_entity.dart';

abstract class ReviewerAssignmentRepository {
  Future<Either<Failure, List<ReviewerAssignmentEntity>>> getReviewerAssignments(
    String tenantId,
  );

  Future<Either<Failure, ReviewerAssignmentEntity>> getReviewerAssignment(
    String assignmentId,
  );

  Future<Either<Failure, ReviewerAssignmentEntity>> createReviewerAssignment({
    required String tenantId,
    required String reviewerId,
    required int gradeMin,
    required int gradeMax,
  });

  Future<Either<Failure, ReviewerAssignmentEntity>> updateReviewerAssignment({
    required String assignmentId,
    required int gradeMin,
    required int gradeMax,
  });

  Future<Either<Failure, void>> deleteReviewerAssignment(String assignmentId);
}
