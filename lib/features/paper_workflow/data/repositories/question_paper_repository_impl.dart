// features/question_papers/data/repositories/question_paper_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/domain/models/paginated_result.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/paper_status.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../domain/repositories/question_paper_repository.dart';
import '../datasources/paper_cloud_data_source.dart';
import '../datasources/paper_local_data_source.dart';
import '../models/question_paper_model.dart';

class QuestionPaperRepositoryImpl implements QuestionPaperRepository {
  final PaperLocalDataSource _localDataSource;
  final PaperCloudDataSource _cloudDataSource;
  final ILogger _logger;
  final UserStateService _userStateService;

  QuestionPaperRepositoryImpl(
      this._localDataSource,
      this._cloudDataSource,
      this._logger,
      this._userStateService,
      );

  Future<String?> _getTenantId() async => _userStateService.currentTenantId;
  Future<String?> _getUserId() async => _userStateService.currentUserId;
  UserRole _getUserRole() => _userStateService.currentRole;
  bool _canCreatePapers() => _userStateService.canCreatePapers();
  bool _canApprovePapers() => _userStateService.canApprovePapers();

  @override
  Future<Either<Failure, QuestionPaperEntity>> saveDraft(QuestionPaperEntity paper) async {
    try {
      if (!paper.status.isDraft) {
        return Left(ValidationFailure('Only draft papers can be saved locally'));
      }

      if (!paper.hasValidQuestions) {
        return Left(ValidationFailure('Paper contains invalid questions: ${paper.validationErrors.join(', ')}'));
      }

      final draftPaper = paper.copyWith(
        status: PaperStatus.draft,
        modifiedAt: DateTime.now(),
        tenantId: null,
        userId: null,
        submittedAt: null,
        reviewedAt: null,
        reviewedBy: null,
      );

      final model = QuestionPaperModel.fromEntity(draftPaper);
      await _localDataSource.saveDraft(model);

      _logger.info('Draft saved', category: LogCategory.paper, context: {
        'paperId': paper.id,
        'title': paper.title,
      });

      return Right(draftPaper);
    } catch (e, stackTrace) {
      _logger.error('Failed to save draft', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(CacheFailure('Failed to save draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getDrafts() async {
    try {
      final models = await _localDataSource.getDrafts();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get drafts', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(CacheFailure('Failed to get drafts: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getDraftById(String id) async {
    try {
      final model = await _localDataSource.getDraftById(id);
      return Right(model?.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to get draft', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(CacheFailure('Failed to get draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDraft(String id) async {
    try {
      await _localDataSource.deleteDraft(id);
      return const Right(null);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete draft', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(CacheFailure('Failed to delete draft: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> submitPaper(QuestionPaperEntity paper) async {
    try {
      final tenantId = await _getTenantId();
      final userId = await _getUserId();

      if (tenantId == null || userId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!_canCreatePapers()) {
        return Left(PermissionFailure('No permission to create papers'));
      }

      if (!paper.canSubmit) {
        return Left(ValidationFailure(_getSubmissionError(paper)));
      }

      // Marks validation for auto-assigned papers
      // If paper is linked to an exam timetable entry, validate marks against exam calendar
      if (paper.examTimetableEntryId != null) {
        final marksValidationError = await _validatePaperMarksAgainstExamCalendar(paper);
        if (marksValidationError != null) {
          return Left(ValidationFailure(marksValidationError));
        }
      }

      _logger.info('Submitting paper', category: LogCategory.paper, context: {
        'draftId': paper.id,
        'title': paper.title,
        'status': paper.status.toString(),
        'subjectId': paper.subjectId,
        'gradeId': paper.gradeId,
        'tenantId': tenantId,
        'userId': userId,
      });

      // Check if this paper already exists in cloud (resubmission scenario)
      final existingPaper = await _cloudDataSource.getPaperById(paper.id);

      final cloudPaper = paper.copyWith(
        // Always keep the generated ID - never use empty string
        status: PaperStatus.submitted,
        tenantId: tenantId,
        userId: userId,
        submittedAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        rejectionReason: null,
        reviewedAt: null,
        reviewedBy: null,
      );

      final model = QuestionPaperModel.fromEntity(cloudPaper);

      _logger.info('Converted to model', category: LogCategory.paper, context: {
        'modelId': model.id,
        'modelTitle': model.title,
      });

      final submittedModel = await _cloudDataSource.submitPaper(model);

      await _localDataSource.deleteDraft(paper.id);

      _logger.info('Paper submitted successfully', category: LogCategory.paper, context: {
        'originalDraftId': paper.id,
        'newSubmittedId': submittedModel.id,
      });

      return Right(submittedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to submit paper', category: LogCategory.paper, error: e, stackTrace: stackTrace, context: {
        'paperId': paper.id,
        'paperTitle': paper.title,
      });

      // Check if it's a unique constraint error
      if (e.toString().contains('duplicate') || e.toString().contains('already exists') || e.toString().contains('unique')) {
        return Left(ValidationFailure('A paper with similar details already exists. Please check if you have already submitted this paper.'));
      }

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
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get submissions', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get submissions: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getPapersForReview() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!_canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final models = await _cloudDataSource.getPapersForReview(tenantId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get papers for review', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> approvePaper(String id) async {
    try {
      final userId = await _getUserId();

      if (!_canApprovePapers() || userId == null) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final model = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.approved.value,
        reviewerId: userId,
      );

      return Right(model.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to approve paper', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to approve paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> rejectPaper(String id, String reason) async {
    try {
      final userId = await _getUserId();

      if (!_canApprovePapers() || userId == null) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      if (reason.trim().isEmpty) {
        return Left(ValidationFailure('Rejection reason required'));
      }

      final model = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.rejected.value,
        reason: reason.trim(),
        reviewerId: userId,
      );

      return Right(model.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to reject paper', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to reject paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> pullForEditing(String id) async {
    try {
      if (!_userStateService.isAuthenticated) {
        return Left(AuthFailure('User not authenticated'));
      }

      final cloudModel = await _cloudDataSource.getPaperById(id);

      if (cloudModel == null) {
        return Left(NotFoundFailure('Paper not found'));
      }

      final cloudEntity = cloudModel.toEntity();

      if (!cloudEntity.status.isRejected) {
        return Left(ValidationFailure('Only rejected papers can be edited'));
      }

      if (!_userStateService.canEditPaper(cloudEntity.userId ?? '')) {
        return Left(PermissionFailure('Can only edit own papers'));
      }

      _logger.info('Pulling rejected paper for editing', category: LogCategory.paper, context: {
        'paperId': id,
        'title': cloudEntity.title,
        'currentStatus': cloudEntity.status.toString(),
      });

      // Save rejection history before converting to draft
      if (cloudEntity.rejectionReason != null && cloudEntity.reviewedBy != null) {
        await _cloudDataSource.saveRejectionHistory(
          paperId: id,
          rejectionReason: cloudEntity.rejectionReason!,
          rejectedBy: cloudEntity.reviewedBy!,
          rejectedAt: cloudEntity.reviewedAt ?? DateTime.now(),
        );

        _logger.info('Saved rejection history', category: LogCategory.paper, context: {
          'paperId': id,
        });
      }

      // Convert the same paper back to draft status (edit in place)
      final updatedModel = await _cloudDataSource.updatePaperStatus(
        id,
        PaperStatus.draft.value,
        clearRejectionData: true,
      );

      final draftEntity = updatedModel.toEntity();

      // Also save as local draft for offline editing
      final localModel = QuestionPaperModel.fromEntity(draftEntity);
      await _localDataSource.saveDraft(localModel);

      _logger.info('Paper converted to draft for editing', category: LogCategory.paper, context: {
        'paperId': id,
        'newStatus': draftEntity.status.toString(),
      });

      return Right(draftEntity);
    } catch (e, stackTrace) {
      _logger.error('Failed to pull for editing', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to pull paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getAllPapersForAdmin() async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      if (!_canApprovePapers()) {
        return Left(PermissionFailure('Admin privileges required'));
      }

      final models = await _cloudDataSource.getAllPapersForAdmin(tenantId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get all papers', category: LogCategory.paper, error: e, stackTrace: stackTrace);
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
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get approved papers', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<QuestionPaperEntity>>> getApprovedPapersPaginated({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
  }) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final result = await _cloudDataSource.getApprovedPapersPaginated(
        tenantId: tenantId,
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        subjectFilter: subjectFilter,
        gradeFilter: gradeFilter,
      );

      final entities = result.items.map((m) => m.toEntity()).toList();

      return Right(PaginatedResult<QuestionPaperEntity>(
        items: entities,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        hasMore: result.hasMore,
        pageSize: result.pageSize,
      ));
    } catch (e, stackTrace) {
      _logger.error('Failed to get paginated approved papers', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get papers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> getApprovedPapersByExamDateRange({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final tenantId = await _getTenantId();

      if (tenantId == null) {
        return Left(AuthFailure('User not authenticated'));
      }

      final models = await _cloudDataSource.getApprovedPapersByExamDateRange(
        tenantId: tenantId,
        fromDate: fromDate,
        toDate: toDate,
      );

      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to get approved papers by exam date range', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get papers: ${e.toString()}'));
    }
  }

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
        status: status,
        userId: createdBy,
      );

      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, stackTrace) {
      _logger.error('Failed to search papers', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to search: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity?>> getPaperById(String id) async {
    try {
      final draftResult = await getDraftById(id);

      return await draftResult.fold(
            (failure) async {
          final cloudModel = await _cloudDataSource.getPaperById(id);
          return Right(cloudModel?.toEntity());
        },
            (draft) async {
          if (draft != null) return Right(draft);

          final cloudModel = await _cloudDataSource.getPaperById(id);
          return Right(cloudModel?.toEntity());
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to get paper', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRejectionHistory(String paperId) async {
    try {
      final history = await _cloudDataSource.getRejectionHistory(paperId);
      return Right(history);
    } catch (e, stackTrace) {
      _logger.error('Failed to get rejection history', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to get rejection history: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, QuestionPaperEntity>> updatePaper(QuestionPaperEntity paper) async {
    try {
      if (!paper.hasValidQuestions) {
        return Left(ValidationFailure('Paper contains invalid questions: ${paper.validationErrors.join(', ')}'));
      }

      final model = QuestionPaperModel.fromEntity(paper);
      final updatedModel = await _cloudDataSource.updatePaper(model);

      _logger.info('Paper updated', category: LogCategory.paper, context: {
        'paperId': paper.id,
        'title': paper.title,
        'status': paper.status.toString(),
      });

      return Right(updatedModel.toEntity());
    } catch (e, stackTrace) {
      _logger.error('Failed to update paper', category: LogCategory.paper, error: e, stackTrace: stackTrace);
      return Left(ServerFailure('Failed to update paper: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<QuestionPaperEntity>>> autoAssignPapersForTimetable({
    required String timetableId,
    required String tenantId,
    required List<Map<String, dynamic>> timetableEntries,
    required String academicYear,
  }) async {
    try {
      final createdPapers = <QuestionPaperEntity>[];

      for (final entry in timetableEntries) {
        final entryId = entry['id'] as String;
        final gradeId = entry['grade_id'] as String;
        final subjectId = entry['subject_id'] as String;
        final section = entry['section'] as String?;
        final examDate = entry['exam_date'] != null
            ? DateTime.parse(entry['exam_date'] as String)
            : null;
        final examType = entry['exam_type'] as String? ?? 'monthlyTest';
        final examNumber = entry['exam_number'] as int?;

        // Get teachers assigned to this entry
        final teachers = entry['teachers'] as List<dynamic>? ?? [];

        // Create a paper for each teacher
        for (final teacherData in teachers) {
          final teacherId = teacherData['teacher_id'] as String;
          final teacherName = teacherData['teacher_name'] as String?;

          // Generate title: "Grade 2 Mathematics - 21 Nov 2025"
          final dateStr = examDate != null
              ? '${examDate.day} ${_monthName(examDate.month)} ${examDate.year}'
              : 'TBD';
          final subjectName = entry['subject_name'] as String? ?? 'Subject';
          final title = 'Grade ${entry['grade_number'] ?? '?'} $subjectName - $dateStr';

          final paper = QuestionPaperEntity(
            id: _generateId(),
            title: title,
            subjectId: subjectId,
            gradeId: gradeId,
            academicYear: academicYear,
            createdBy: teacherId,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            status: PaperStatus.draft,
            examDate: examDate,
            examType: _parseExamType(examType),
            examNumber: examNumber,
            paperSections: [],
            questions: {},
            tenantId: tenantId,
            userId: teacherId,
            examTimetableEntryId: entryId,
            section: section,
          );

          // Save the auto-assigned paper (use submitPaper which handles creation)
          final model = QuestionPaperModel.fromEntity(paper);
          final savedModel = await _cloudDataSource.submitPaper(model);
          createdPapers.add(savedModel.toEntity());

          _logger.info(
            'Paper auto-assigned to teacher',
            category: LogCategory.paper,
            context: {
              'paperId': paper.id,
              'teacherId': teacherId,
              'teacherName': teacherName,
              'title': paper.title,
              'timetableEntryId': entryId,
            },
          );
        }
      }

      return Right(createdPapers);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to auto-assign papers for timetable',
        category: LogCategory.paper,
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure('Failed to auto-assign papers: ${e.toString()}'));
    }
  }

  /// Generate a unique ID for new papers
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           (DateTime.now().microsecond % 1000).toString();
  }

  /// Convert month number to month name
  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Parse exam type string to ExamType enum
  ExamType _parseExamType(String examType) {
    switch (examType.toLowerCase()) {
      case 'monthlytest':
      case 'monthly':
        return ExamType.monthlyTest;
      case 'dailytest':
      case 'daily':
        return ExamType.dailyTest;
      case 'quarterlyexam':
      case 'quarterly':
        return ExamType.quarterlyExam;
      case 'annualexam':
      case 'annual':
      case 'finalexam':
      case 'final':
        return ExamType.annualExam;
      default:
        return ExamType.monthlyTest;
    }
  }

  /// Validate paper marks against exam calendar marks config
  ///
  /// For auto-assigned papers with exam_timetable_entry_id:
  /// 1. Fetch the exam timetable entry
  /// 2. Get the associated exam calendar via the timetable
  /// 3. Extract marks_config (List<MarkConfigEntity>)
  /// 4. Find matching grade range for the paper's grade_id
  /// 5. Validate: paper.totalMarks <= marks_config.totalMarks
  ///
  /// Returns:
  /// - null if validation passes
  /// - Error message string if validation fails
  ///
  /// Note: This requires access to exam_timetable_entries and exam_calendars tables
  /// Current implementation uses a placeholder - full validation should be implemented
  /// by fetching actual exam calendar marks config
  Future<String?> _validatePaperMarksAgainstExamCalendar(QuestionPaperEntity paper) async {
    try {
      // TODO: Implement full marks validation
      // 1. Use exam_timetable_entry_id to fetch entry from database
      // 2. Get timetable_id from entry
      // 3. Fetch exam_calendar linked to timetable_id
      // 4. Extract marks_config for paper's grade range
      // 5. Compare paper.totalMarks with max_marks

      // For now, we allow submission but log the total marks
      _logger.info(
        'Paper marks for exam calendar validation',
        category: LogCategory.paper,
        context: {
          'paperId': paper.id,
          'totalMarks': paper.totalMarks,
          'examTimetableEntryId': paper.examTimetableEntryId,
        },
      );

      // Placeholder: No marks validation failure for now
      // Will be fully implemented with access to exam calendar data
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error validating paper marks against exam calendar',
        category: LogCategory.paper,
        error: e,
        stackTrace: stackTrace,
      );
      // Don't fail submission due to validation error - just log it
      return null;
    }
  }
}