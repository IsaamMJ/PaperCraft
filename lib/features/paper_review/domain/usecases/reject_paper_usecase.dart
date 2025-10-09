import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/repositories/question_paper_repository.dart';
import '../../../notifications/domain/usecases/create_notification_usecase.dart';

class RejectPaperUseCase {
  final QuestionPaperRepository repository;
  final CreateNotificationUseCase createNotificationUseCase;
  final ILogger logger;

  RejectPaperUseCase(
    this.repository,
    this.createNotificationUseCase,
    this.logger,
  );

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId, String reason) async {
    // Enhanced validation
    if (reason.trim().isEmpty) {
      return Left(ValidationFailure('Rejection reason is required'));
    }

    if (reason.trim().length < 10) {
      return Left(ValidationFailure('Rejection reason must be at least 10 characters'));
    }

    if (reason.trim().length > 500) {
      return Left(ValidationFailure('Rejection reason cannot exceed 500 characters'));
    }

    final result = await repository.rejectPaper(paperId, reason.trim());

    return result.fold(
      (failure) => Left(failure),
      (paper) async {
        // Send notification to the teacher
        if (paper.userId != null && paper.tenantId != null) {
          try {
            await createNotificationUseCase(
              userId: paper.userId!,
              tenantId: paper.tenantId!,
              type: 'paper_rejected',
              title: 'Paper Rejected',
              message: 'Your paper "${paper.title}" was rejected. Reason: ${reason.trim()}',
              data: {
                'paperId': paper.id,
                'paperTitle': paper.title,
                'rejectionReason': reason.trim(),
              },
            );

            logger.info('Rejection notification sent', category: LogCategory.paper, context: {
              'paperId': paper.id,
              'userId': paper.userId,
            });
          } catch (e) {
            // Log but don't fail the rejection if notification fails
            logger.warning('Failed to send rejection notification',
                category: LogCategory.system,
                context: {
                  'error': e.toString(),
                  'paperId': paper.id,
                });
          }
        }

        return Right(paper);
      },
    );
  }
}