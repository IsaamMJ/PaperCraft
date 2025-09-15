// features/question_papers/data/repositories/question_paper_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/permission_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../../domain/repositories/question_paper_repository.dart';
import '../datasources/paper_local_data_source.dart';
import '../datasources/paper_cloud_data_source.dart';
import '../models/question_paper_model.dart';

class QuestionPaperRepositoryImpl implements QuestionPaperRepository {
  final PaperLocalDataSource _localDataSource;
  final PaperCloudDataSource _cloudDataSource;

  QuestionPaperRepositoryImpl(this._localDataSource, this._cloudDataSource);

  // =============== HELPER METHODS ===============

  Future<String?> _getTenantId() async {
    return await PermissionService.getCurrentTenantId();
  }

  Future<String?> _getUserId() async {
    return await PermissionService.getCurrentUserId();
  }

  Future<UserRole> _getUserRole() async {
    return await PermissionService.getCurrentUserRole();
  }

  // =============== DRAFT OPERATIONS (Local Storage Only) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> saveDraft(QuestionPaperEntity paper) async {
    try {
      // Ensure it's a draft and validate
      if (!paper.status.isDraft) {
        return Left(ValidationFailure('Only draft papers can be saved locally'));
      }

      // Validate paper structure
      if (!paper.hasValidQuestions) {
        return Left(ValidationFailure('Paper contains invalid questions: ${paper.validationErrors.join(', ')}'));
      }

      final draftPaper = paper.copyWith(
        status: PaperStatus.draft,
        modifiedAt: DateTime.now(),
        // Clear cloud fields for local storage
        tenantId: null,
        userId: null,
        submittedAt: null,
        reviewedAt: null,
        reviewedBy: null,
      );

      final model = QuestionPaperModel.fromEntity(draftPaper);
      await _localDataSource.saveDraft(model);

      return Right(draftPaper);
    } catch (e) {
      return Left(CacheFailure('Failed to save draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getDrafts() async {
    try {
      final models = await _localDataSource.getDrafts();
      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure('Failed to get drafts: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getDraftById(String id) async {
    try {
      final model = await _localDataSource.getDraftById(id);
      final entity = model?.toEntity();
      return Right(entity);
    } catch (e) {
      return Left(CacheFailure('Failed to get draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDraft(String id) async {
    try {
      await _localDataSource.deleteDraft(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to delete draft: ${e.toString()}'));
    }
  }

  // =============== SUBMISSION OPERATIONS (Cloud Storage) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> submitPaper(QuestionPaperEntity paper) async {
    try {
      final tenantId = await _getTenantId();
      final userId = await _getUserId();
      final userRole = await _getUserRole();

      if (tenantId == null || userId == null) {
        return Left(AuthFailure('User not authenticated - missing tenant or user ID'));
      }

      if (!PermissionService.canCreatePapers(userRole)) {
        return Left(PermissionFailure('User does not have permission to create papers'));
      }

      if (!paper.canSubmit) {
        return Left(ValidationFailure('Paper cannot be submitted: ${_getSubmissionError(paper)}'));
      }

      // Create cloud version for submission
      final cloudPaper = paper.createCloudVersion(
        tenantId: tenantId,
        userId: userId,
      );

      final model = QuestionPaperModel.fromEntity(cloudPaper);
      final submittedModel = await _cloudDataSource.submitPaper(model);

      // Remove from local drafts after successful submission
      await _localDataSource.deleteDraft(paper.id);

      return Right(submittedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to submit paper: ${e.toString()}'));
    }
  }

  String _getSubmissionError(QuestionPaperEntity paper) {
    if (!paper.status.isDraft) return 'Only drafts can be submitted';
    if (paper.questions.isEmpty) return 'Paper must have questions';
    if (paper.title.trim().isEmpty) return 'Paper must have a title';
    if (!paper.isComplete) return 'Paper requirements not met: ${paper.validationErrors.join(', ')}';
    return 'Paper is incomplete';
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getUserSubmissions() async {
    try {
      final tenantId = await _getTenantId();
      final userId = await _getUserId();

      if (tenantId == null || userId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _cloudDataSource.getUserSubmissions(tenantId, userId);
      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(ServerFailure('Failed to get user submissions: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getPapersForReview() async {
    try {
      final tenantId = await _getTenantId();
      final userRole = await _getUserRole();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!PermissionService.canApprovePapers(userRole)) {
        return Left(PermissionFailure('Admin privileges required for reviewing papers'));
      }

      final models = await _cloudDataSource.getPapersForReview(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(ServerFailure('Failed to get papers for review: ${e.toString()}'));
    }
  }

  // =============== APPROVAL OPERATIONS (Admin Only) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> approvePaper(String id) async {
    try {
      final userRole = await _getUserRole();
      final userId = await _getUserId();

      if (!PermissionService.canApprovePapers(userRole)) {
        return Left(PermissionFailure('Admin privileges required to approve papers'));
      }

      if (userId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final updatedModel = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.approved.value,
        reviewerId: userId,
      );

      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to approve paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> rejectPaper(String id, String reason) async {
    try {
      final userRole = await _getUserRole();
      final userId = await _getUserId();

      if (!PermissionService.canApprovePapers(userRole)) {
        return Left(PermissionFailure('Admin privileges required to reject papers'));
      }

      if (userId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (reason.trim().isEmpty) {
        return Left(ValidationFailure('Rejection reason is required'));
      }

      final updatedModel = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.rejected.value,
        reason: reason.trim(),
        reviewerId: userId,
      );

      return Right(updatedModel.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to reject paper: ${e.toString()}'));
    }
  }

  // =============== EDITING OPERATIONS ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> pullForEditing(String id) async {
    try {
      final userId = await _getUserId();
      final userRole = await _getUserRole();

      if (userId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final cloudModel = await _cloudDataSource.getPaperById(id);

      if (cloudModel == null) {
        return Left(NotFoundFailure('Paper not found'));
      }

      final cloudEntity = cloudModel.toEntity();

      // Verify status and permissions
      if (!cloudEntity.status.isRejected) {
        return Left(ValidationFailure('Only rejected papers can be pulled for editing'));
      }

      // Check ownership or admin rights
      if (!PermissionService.canEditPaper(cloudEntity.userId ?? '', userId, userRole)) {
        return Left(PermissionFailure('You can only edit your own papers'));
      }

      // Create new draft copy and save locally
      final editablePaper = cloudEntity.createDraftCopy();
      return await saveDraft(editablePaper);
    } catch (e) {
      return Left(ServerFailure('Failed to pull paper for editing: ${e.toString()}'));
    }
  }

  // =============== SEARCH AND QUERY ===============

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> searchPapers({
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  }) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _cloudDataSource.searchPapers(
        tenantId,
        title: title,
        subject: subject,
        status: status,
        userId: createdBy,
      );

      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } catch (e) {
      return Left(ServerFailure('Failed to search papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getPaperById(String id) async {
    try {
      // First check if it's a local draft
      final draftResult = await getDraftById(id);

      return await draftResult.fold(
            (failure) async {
          // If not found locally or error, try cloud
          try {
            final cloudModel = await _cloudDataSource.getPaperById(id);
            final entity = cloudModel?.toEntity();
            return Right(entity);
          } catch (e) {
            return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
          }
        },
            (draft) async {
          if (draft != null) {
            return Right(draft);
          } else {
            // Try cloud if local draft is null
            try {
              final cloudModel = await _cloudDataSource.getPaperById(id);
              final entity = cloudModel?.toEntity();
              return Right(entity);
            } catch (e) {
              return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
            }
          }
        },
      );
    } catch (e) {
      return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
    }
  }
}