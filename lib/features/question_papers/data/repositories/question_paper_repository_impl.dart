// features/question_papers/data/repositories/question_paper_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../../domain/repositories/question_paper_repository.dart';
import '../datasources/paper_local_data_source.dart';
import '../datasources/paper_cloud_data_source.dart';
import '../models/question_paper_model.dart';

class QuestionPaperRepositoryImpl implements QuestionPaperRepository {
  final PaperLocalDataSource _localDataSource;
  final PaperCloudDataSource _cloudDataSource;
  final ILogger _logger;

  QuestionPaperRepositoryImpl(
      this._localDataSource,
      this._cloudDataSource,
      this._logger,
      );

  // =============== HELPER METHODS ===============

  Future<String?> _getTenantId() async {
    return sl<UserStateService>().currentTenantId;
  }

  Future<String?> _getUserId() async {
    return sl<UserStateService>().currentUserId;
  }

  UserRole _getUserRole() {
    return sl<UserStateService>().currentRole;
  }

  bool _canCreatePapers() {
    return sl<UserStateService>().canCreatePapers();
  }

  bool _canApprovePapers() {
    return sl<UserStateService>().canApprovePapers();
  }

  bool _canEditPaper(String paperUserId) {
    return sl<UserStateService>().canEditPaper(paperUserId);
  }

  // =============== DRAFT OPERATIONS (Local Storage Only) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> saveDraft(QuestionPaperEntity paper) async {
    try {
      _logger.debug('Saving draft paper', category: LogCategory.paper, context: {
        'paperId': paper.id,
        'title': paper.title,
        'subject': paper.subject,
        'operation': 'save_draft',
      });

      // Ensure it's a draft and validate
      if (!paper.status.isDraft) {
        _logger.warning('Attempted to save non-draft paper as draft',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'actualStatus': paper.status.value,
              'operation': 'save_draft',
            }
        );
        return Left(ValidationFailure('Only draft papers can be saved locally'));
      }

      // Validate paper structure
      if (!paper.hasValidQuestions) {
        _logger.warning('Paper validation failed',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'validationErrors': paper.validationErrors,
              'operation': 'save_draft',
            }
        );
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

      _logger.info('Draft paper saved successfully', category: LogCategory.paper, context: {
        'paperId': paper.id,
        'title': paper.title,
        'subject': paper.subject,
        'questionCount': paper.questions.values.fold(0, (sum, questions) => sum + questions.length),
        'operation': 'save_draft',
      });

      return Right(draftPaper);
    } catch (e, stackTrace) {
      _logger.error('Failed to save draft paper',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': paper.id,
            'title': paper.title,
            'operation': 'save_draft',
          }
      );
      return Left(CacheFailure('Failed to save draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getDrafts() async {
    try {
      _logger.debug('Fetching all draft papers', category: LogCategory.paper);

      final models = await _localDataSource.getDrafts();
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Draft papers fetched successfully', category: LogCategory.paper, context: {
        'draftsCount': entities.length,
        'operation': 'get_drafts',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch draft papers',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {'operation': 'get_drafts'}
      );
      return Left(CacheFailure('Failed to get drafts: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getDraftById(String id) async {
    try {
      _logger.debug('Fetching draft paper by ID', category: LogCategory.paper, context: {
        'paperId': id,
        'operation': 'get_draft_by_id',
      });

      final model = await _localDataSource.getDraftById(id);
      final entity = model?.toEntity();

      if (entity != null) {
        _logger.debug('Draft paper found', category: LogCategory.paper, context: {
          'paperId': id,
          'title': entity.title,
          'operation': 'get_draft_by_id',
        });
      } else {
        _logger.debug('Draft paper not found', category: LogCategory.paper, context: {
          'paperId': id,
          'operation': 'get_draft_by_id',
        });
      }

      return Right(entity);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch draft paper by ID',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'get_draft_by_id',
          }
      );
      return Left(CacheFailure('Failed to get draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDraft(String id) async {
    try {
      _logger.debug('Deleting draft paper', category: LogCategory.paper, context: {
        'paperId': id,
        'operation': 'delete_draft',
      });

      await _localDataSource.deleteDraft(id);

      _logger.info('Draft paper deleted successfully', category: LogCategory.paper, context: {
        'paperId': id,
        'operation': 'delete_draft',
      });

      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete draft paper',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'delete_draft',
          }
      );
      return Left(CacheFailure('Failed to delete draft: ${e.toString()}'));
    }
  }

  // =============== SUBMISSION OPERATIONS (Cloud Storage) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> submitPaper(QuestionPaperEntity paper) async {
    try {
      _logger.info('Starting paper submission', category: LogCategory.paper, context: {
        'paperId': paper.id,
        'title': paper.title,
        'subject': paper.subject,
        'operation': 'submit_paper',
      });

      final tenantId = await _getTenantId();
      final userId = await _getUserId();

      if (tenantId == null || userId == null) {
        _logger.warning('Paper submission failed - authentication required',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'hasTenantId': tenantId != null,
              'hasUserId': userId != null,
              'operation': 'submit_paper',
            }
        );
        return Left(AuthFailure('User not authenticated - missing tenant or user ID'));
      }

      if (!_canCreatePapers()) {
        _logger.warning('Paper submission failed - insufficient permissions',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'userId': userId,
              'userRole': _getUserRole().toString(),
              'operation': 'submit_paper',
            }
        );
        return Left(PermissionFailure('User does not have permission to create papers'));
      }

      if (!paper.canSubmit) {
        final submissionError = _getSubmissionError(paper);
        _logger.warning('Paper submission failed - validation error',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'validationError': submissionError,
              'operation': 'submit_paper',
            }
        );
        return Left(ValidationFailure('Paper cannot be submitted: $submissionError'));
      }

      // Create cloud version WITHOUT ID (let Supabase generate UUID)
      final cloudPaper = paper.copyWith(
        id: '', // Empty ID - let Supabase generate UUID
        status: PaperStatus.submitted,
        tenantId: tenantId,
        userId: userId,
        submittedAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        // Clear local-only fields
        rejectionReason: null,
        reviewedAt: null,
        reviewedBy: null,
      );

      final model = QuestionPaperModel.fromEntity(cloudPaper);
      final submittedModel = await _cloudDataSource.submitPaper(model);

      // Remove from local drafts after successful submission
      await _localDataSource.deleteDraft(paper.id);

      _logger.info('Paper submitted successfully', category: LogCategory.paper, context: {
        'originalDraftId': paper.id,
        'newCloudId': submittedModel.id,
        'title': paper.title,
        'subject': paper.subject,
        'tenantId': tenantId,
        'userId': userId,
        'submittedAt': submittedModel.submittedAt?.toIso8601String(),
        'operation': 'submit_paper',
      });

      return Right(submittedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to submit paper',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': paper.id,
            'title': paper.title,
            'operation': 'submit_paper',
          }
      );
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

      _logger.debug('Fetching user submissions', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'userId': userId,
        'operation': 'get_user_submissions',
      });

      if (tenantId == null || userId == null) {
        _logger.warning('Failed to fetch user submissions - authentication required',
            category: LogCategory.paper,
            context: {
              'hasTenantId': tenantId != null,
              'hasUserId': userId != null,
              'operation': 'get_user_submissions',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _cloudDataSource.getUserSubmissions(tenantId, userId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('User submissions fetched successfully', category: LogCategory.paper, context: {
        'submissionsCount': entities.length,
        'tenantId': tenantId,
        'userId': userId,
        'operation': 'get_user_submissions',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch user submissions',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {'operation': 'get_user_submissions'}
      );
      return Left(ServerFailure('Failed to get user submissions: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getPapersForReview() async {
    try {
      final tenantId = await _getTenantId();
      final userRole = _getUserRole();

      _logger.debug('Fetching papers for review', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'userRole': userRole.toString(),
        'operation': 'get_papers_for_review',
      });

      if (tenantId == null) {
        _logger.warning('Failed to fetch papers for review - authentication required',
            category: LogCategory.paper,
            context: {
              'hasTenantId': tenantId != null,
              'userRole': userRole.toString(),
              'operation': 'get_papers_for_review',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      if (!_canApprovePapers()) {
        _logger.warning('Failed to fetch papers for review - insufficient permissions',
            category: LogCategory.paper,
            context: {
              'userRole': userRole.toString(),
              'operation': 'get_papers_for_review',
            }
        );
        return Left(PermissionFailure('Admin privileges required for reviewing papers'));
      }

      final models = await _cloudDataSource.getPapersForReview(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Papers for review fetched successfully', category: LogCategory.paper, context: {
        'papersCount': entities.length,
        'tenantId': tenantId,
        'userRole': userRole.toString(),
        'operation': 'get_papers_for_review',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch papers for review',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {'operation': 'get_papers_for_review'}
      );
      return Left(ServerFailure('Failed to get papers for review: ${e.toString()}'));
    }
  }

  // =============== APPROVAL OPERATIONS (Admin Only) ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> approvePaper(String id) async {
    try {
      final userId = await _getUserId();
      final userRole = _getUserRole();

      _logger.info('Starting paper approval', category: LogCategory.paper, context: {
        'paperId': id,
        'reviewerId': userId,
        'reviewerRole': userRole.toString(),
        'operation': 'approve_paper',
      });

      if (!_canApprovePapers()) {
        _logger.warning('Paper approval failed - insufficient permissions',
            category: LogCategory.paper,
            context: {
              'paperId': id,
              'reviewerId': userId,
              'reviewerRole': userRole.toString(),
              'operation': 'approve_paper',
            }
        );
        return Left(PermissionFailure('Admin privileges required to approve papers'));
      }

      if (userId == null) {
        _logger.warning('Paper approval failed - authentication required',
            category: LogCategory.paper,
            context: {
              'paperId': id,
              'operation': 'approve_paper',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      final updatedModel = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.approved.value,
        reviewerId: userId,
      );

      _logger.info('Paper approved successfully', category: LogCategory.paper, context: {
        'paperId': id,
        'reviewerId': userId,
        'reviewerRole': userRole.toString(),
        'reviewedAt': updatedModel.reviewedAt?.toIso8601String(),
        'operation': 'approve_paper',
      });

      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to approve paper',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'approve_paper',
          }
      );
      return Left(ServerFailure('Failed to approve paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> rejectPaper(String id, String reason) async {
    try {
      final userId = await _getUserId();
      final userRole = _getUserRole();

      _logger.info('Starting paper rejection', category: LogCategory.paper, context: {
        'paperId': id,
        'reviewerId': userId,
        'reviewerRole': userRole.toString(),
        'hasReason': reason.trim().isNotEmpty,
        'operation': 'reject_paper',
      });

      if (!_canApprovePapers()) {
        _logger.warning('Paper rejection failed - insufficient permissions',
            category: LogCategory.paper,
            context: {
              'paperId': id,
              'reviewerId': userId,
              'reviewerRole': userRole.toString(),
              'operation': 'reject_paper',
            }
        );
        return Left(PermissionFailure('Admin privileges required to reject papers'));
      }

      if (userId == null) {
        _logger.warning('Paper rejection failed - authentication required',
            category: LogCategory.paper,
            context: {
              'paperId': id,
              'operation': 'reject_paper',
            }
        );
        return Left(AuthFailure('User not authenticated'));
      }

      if (reason.trim().isEmpty) {
        _logger.warning('Paper rejection failed - reason required',
            category: LogCategory.paper,
            context: {
              'paperId': id,
              'reviewerId': userId,
              'operation': 'reject_paper',
            }
        );
        return Left(ValidationFailure('Rejection reason is required'));
      }

      final updatedModel = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.rejected.value,
        reason: reason.trim(),
        reviewerId: userId,
      );

      _logger.info('Paper rejected successfully', category: LogCategory.paper, context: {
        'paperId': id,
        'reviewerId': userId,
        'reviewerRole': userRole.toString(),
        'rejectionReason': reason.trim(),
        'reviewedAt': updatedModel.reviewedAt?.toIso8601String(),
        'operation': 'reject_paper',
      });

      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to reject paper',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'reject_paper',
          }
      );
      return Left(ServerFailure('Failed to reject paper: ${e.toString()}'));
    }
  }

  // =============== EDITING OPERATIONS ===============

  @override
  Future<Either<Failure, QuestionPaperEntity>> pullForEditing(String id) async {
    try {
      final userStateService = sl<UserStateService>();

      _logger.info('Starting pull for editing', category: LogCategory.paper, context: {
        'originalPaperId': id,
        'isAuthenticated': userStateService.isAuthenticated,
        'operation': 'pull_for_editing',
      });

      if (!userStateService.isAuthenticated) {
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

      if (!userStateService.canEditPaper(cloudEntity.userId ?? '')) {
        return Left(PermissionFailure('You can only edit your own papers'));
      }

      // CREATE NEW ID FOR THE DRAFT VERSION (simple timestamp)
      final newDraftId = 'draft_${DateTime.now().millisecondsSinceEpoch}';

      // Convert the rejected paper to a NEW draft with NEW ID
      final draftPaper = cloudEntity.copyWith(
        id: newDraftId,  // <- NEW ID HERE
        status: PaperStatus.draft,
        modifiedAt: DateTime.now(),
        rejectionReason: null,  // Clear rejection data
        submittedAt: null,
        reviewedAt: null,
        reviewedBy: null,
        // Clear cloud-specific fields for local storage
        tenantId: null,
        userId: null,
      );

      // Save the NEW draft locally (with new ID)
      final localModel = QuestionPaperModel.fromEntity(draftPaper);
      await _localDataSource.saveDraft(localModel);

      _logger.info('Paper converted to new draft successfully', category: LogCategory.paper, context: {
        'originalPaperId': id,
        'newDraftId': newDraftId,
        'originalTitle': cloudEntity.title,
        'operation': 'pull_for_editing',
      });

      return Right(draftPaper);
    } catch (e, stackTrace) {
      _logger.error('Failed to pull paper for editing',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'pull_for_editing',
          }
      );
      return Left(ServerFailure('Failed to pull paper for editing: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getAllPapersForAdmin() async {
    try {
      final tenantId = await _getTenantId();
      final userRole = _getUserRole();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!_canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final models = await _cloudDataSource.getAllPapersForAdmin(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('All papers fetched for admin', category: LogCategory.paper, context: {
        'papersCount': entities.length,
        'tenantId': tenantId,
        'userRole': userRole.toString(),
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch all papers for admin',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getApprovedPapers() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _cloudDataSource.getApprovedPapers(tenantId);
      final entities = models.map((model) => model.toEntity()).toList();

      _logger.info('Approved papers fetched', category: LogCategory.paper, context: {
        'papersCount': entities.length,
        'tenantId': tenantId,
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch approved papers',
          category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get approved papers: ${e.toString()}'));
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

      _logger.debug('Searching papers', category: LogCategory.paper, context: {
        'tenantId': tenantId,
        'hasTitle': title != null,
        'hasSubject': subject != null,
        'hasStatus': status != null,
        'hasCreatedBy': createdBy != null,
        'operation': 'search_papers',
      });

      if (tenantId == null) {
        _logger.warning('Paper search failed - authentication required',
            category: LogCategory.paper,
            context: {'operation': 'search_papers'}
        );
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

      _logger.info('Paper search completed successfully', category: LogCategory.paper, context: {
        'resultsCount': entities.length,
        'searchFilters': {
          'title': title,
          'subject': subject,
          'status': status,
          'createdBy': createdBy,
        },
        'operation': 'search_papers',
      });

      return Right(entities);
    } catch (e, stackTrace) {
      _logger.error('Failed to search papers',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'searchFilters': {
              'title': title,
              'subject': subject,
              'status': status,
              'createdBy': createdBy,
            },
            'operation': 'search_papers',
          }
      );
      return Left(ServerFailure('Failed to search papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getPaperById(String id) async {
    try {
      _logger.debug('Fetching paper by ID', category: LogCategory.paper, context: {
        'paperId': id,
        'operation': 'get_paper_by_id',
      });

      // First check if it's a local draft
      final draftResult = await getDraftById(id);

      return await draftResult.fold(
            (failure) async {
          // If not found locally or error, try cloud
          _logger.debug('Draft not found locally, trying cloud', category: LogCategory.paper, context: {
            'paperId': id,
            'localFailure': failure.toString(),
            'operation': 'get_paper_by_id',
          });

          try {
            final cloudModel = await _cloudDataSource.getPaperById(id);
            final entity = cloudModel?.toEntity();

            if (entity != null) {
              _logger.debug('Paper found in cloud', category: LogCategory.paper, context: {
                'paperId': id,
                'title': entity.title,
                'status': entity.status.value,
                'operation': 'get_paper_by_id',
              });
            } else {
              _logger.debug('Paper not found in cloud', category: LogCategory.paper, context: {
                'paperId': id,
                'operation': 'get_paper_by_id',
              });
            }

            return Right(entity);
          } catch (e) {
            _logger.error('Failed to fetch paper from cloud',
                category: LogCategory.paper,
                error: e,
                context: {
                  'paperId': id,
                  'operation': 'get_paper_by_id',
                }
            );
            return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
          }
        },
            (draft) async {
          if (draft != null) {
            _logger.debug('Paper found in local drafts', category: LogCategory.paper, context: {
              'paperId': id,
              'title': draft.title,
              'operation': 'get_paper_by_id',
            });
            return Right(draft);
          } else {
            // Try cloud if local draft is null
            _logger.debug('Local draft is null, trying cloud', category: LogCategory.paper, context: {
              'paperId': id,
              'operation': 'get_paper_by_id',
            });

            try {
              final cloudModel = await _cloudDataSource.getPaperById(id);
              final entity = cloudModel?.toEntity();

              if (entity != null) {
                _logger.debug('Paper found in cloud after null draft', category: LogCategory.paper, context: {
                  'paperId': id,
                  'title': entity.title,
                  'status': entity.status.value,
                  'operation': 'get_paper_by_id',
                });
              }

              return Right(entity);
            } catch (e) {
              _logger.error('Failed to fetch paper from cloud after null draft',
                  category: LogCategory.paper,
                  error: e,
                  context: {
                    'paperId': id,
                    'operation': 'get_paper_by_id',
                  }
              );
              return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
            }
          }
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get paper by ID',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace,
          context: {
            'paperId': id,
            'operation': 'get_paper_by_id',
          }
      );
      return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
    }
  }
}