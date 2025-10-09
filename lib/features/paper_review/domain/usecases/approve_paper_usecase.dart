import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/repositories/question_paper_repository.dart';
import '../../../notifications/domain/usecases/create_notification_usecase.dart';

class ApprovePaperUseCase {
  final QuestionPaperRepository repository;
  final CreateNotificationUseCase createNotificationUseCase;
  final ILogger logger;

  ApprovePaperUseCase(
    this.repository,
    this.createNotificationUseCase,
    this.logger,
  );

  Future<Either<Failure, QuestionPaperEntity>> call(String paperId) async {
    final result = await repository.approvePaper(paperId);

    return result.fold(
      (failure) => Left(failure),
      (paper) async {
        // Send notification to the teacher
        if (paper.userId != null && paper.tenantId != null) {
          try {
            await createNotificationUseCase(
              userId: paper.userId!,
              tenantId: paper.tenantId!,
              type: 'paper_approved',
              title: 'Paper Approved',
              message: 'Your paper "${paper.title}" has been approved!',
              data: {
                'paperId': paper.id,
                'paperTitle': paper.title,
              },
            );

            logger.info('Approval notification sent', category: LogCategory.paper, context: {
              'paperId': paper.id,
              'userId': paper.userId,
            });
          } catch (e) {
            // Log but don't fail the approval if notification fails
            logger.warning('Failed to send approval notification',
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