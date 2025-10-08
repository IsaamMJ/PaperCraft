// features/question_papers/data/datasources/paper_cloud_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/network/models/api_response.dart';
import '../models/question_paper_model.dart';

abstract class PaperCloudDataSource {
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper);
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId);
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId);
  Future<QuestionPaperModel> updatePaperStatus(String id, String status, {String? reason, String? reviewerId, bool clearRejectionData = false});
  Future<QuestionPaperModel?> getPaperById(String id);
  Future<void> deletePaper(String id);
  Future<List<QuestionPaperModel>> getAllPapersForAdmin(String tenantId);
  Future<List<QuestionPaperModel>> getApprovedPapers(String tenantId);
  Future<List<QuestionPaperModel>> searchPapers(
      String tenantId, {
        String? title,
        String? status,
        String? userId,
      });
  Future<void> saveRejectionHistory({
    required String paperId,
    required String rejectionReason,
    required String rejectedBy,
    required DateTime rejectedAt,
  });
  Future<List<Map<String, dynamic>>> getRejectionHistory(String paperId);
}

class PaperCloudDataSourceImpl implements PaperCloudDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'question_papers';
  static const String _viewName = 'question_papers_enriched';

  PaperCloudDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper) async {
    try {
      _logger.paperAction('submit_paper_started', paper.id, context: {
        'title': paper.title,
        'subjectId': paper.subjectId,
        'gradeId': paper.gradeId,
        'examTypeId': paper.examTypeId,
        'academicYear': paper.academicYear,
        'tenantId': paper.tenantId,
        'userId': paper.userId,
      });

      final data = paper.toSupabaseMap();

      // Check if this is a resubmission (paper already exists in cloud)
      final existingPaper = await getPaperById(paper.id);

      ApiResponse<QuestionPaperModel> response;

      if (existingPaper != null) {
        // This is a resubmission - UPDATE the existing paper
        _logger.info('Resubmitting existing paper', category: LogCategory.paper, context: {
          'paperId': paper.id,
          'title': paper.title,
        });

        response = await _apiClient.update<QuestionPaperModel>(
          table: _tableName,
          data: data,
          filters: {'id': paper.id},
          fromJson: QuestionPaperModel.fromSupabase,
        );
      } else {
        // This is a new submission - INSERT
        _logger.info('Submitting new paper', category: LogCategory.paper, context: {
          'title': paper.title,
        });

        response = await _apiClient.insert<QuestionPaperModel>(
          table: _tableName,
          data: data,
          fromJson: QuestionPaperModel.fromSupabase,
        );
      }

      if (response.isSuccess) {
        _logger.paperAction('submit_paper_success', response.data!.id, context: {
          'title': paper.title,
          'submittedAt': response.data!.submittedAt?.toIso8601String(),
          'isResubmission': existingPaper != null,
        });
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to submit paper');
      }
    } catch (e, stackTrace) {
      _logger.paperError('submit_paper', paper.id, e);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getAllPapersForAdmin(String tenantId) async {
    try {
      _logger.debug('Fetching all papers for admin',
          category: LogCategory.storage,
          context: {'tenantId': tenantId});

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: {'tenant_id': tenantId},
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get papers');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch all papers',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getApprovedPapers(String tenantId) async {
    try {
      final response = await _apiClient.select<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: {
          'tenant_id': tenantId,
          'status': 'approved',
        },
        orderBy: 'reviewed_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get approved papers');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch approved papers',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId) async {
    try {
      final response = await _apiClient.select<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: {
          'tenant_id': tenantId,
          'user_id': userId,
        },
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get user submissions');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch user submissions',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId) async {
    try {
      final response = await _apiClient.select<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: {
          'tenant_id': tenantId,
          'status': 'submitted',
        },
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get papers for review');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch papers for review',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> searchPapers(
      String tenantId, {
        String? title,
        String? status,
        String? userId,
      }) async {
    try {
      final filters = <String, dynamic>{
        'tenant_id': tenantId,
      };

      if (status != null && status.isNotEmpty) {
        filters['status'] = status;
      }

      if (userId != null && userId.isNotEmpty) {
        filters['user_id'] = userId;
      }

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: filters,
        orderBy: 'created_at',
        ascending: false,
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to search papers');
      }

      var results = response.data!;

      if (title != null && title.isNotEmpty) {
        final titleLower = title.toLowerCase();
        results = results.where((paper) =>
            paper.title.toLowerCase().contains(titleLower)
        ).toList();
      }

      return results;
    } catch (e, stackTrace) {
      _logger.error('Failed to search papers',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<QuestionPaperModel> updatePaperStatus(
      String id,
      String status,
      {String? reason, String? reviewerId, bool clearRejectionData = false}
      ) async {
    try {
      _logger.paperAction('update_paper_status_started', id, context: {
        'newStatus': status,
        'reason': reason,
        'reviewerId': reviewerId,
        'clearRejectionData': clearRejectionData,
      });

      final updateData = <String, dynamic>{
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
      };

      if (clearRejectionData) {
        updateData['rejection_reason'] = null;
        updateData['reviewed_by'] = null;
        updateData['reviewed_at'] = null;
      } else {
        if (reason != null && reason.isNotEmpty) {
          updateData['rejection_reason'] = reason;
        }

        if (reviewerId != null) {
          updateData['reviewed_by'] = reviewerId;
        }
      }

      final response = await _apiClient.update<QuestionPaperModel>(
        table: _tableName,
        data: updateData,
        filters: {'id': id},
        fromJson: QuestionPaperModel.fromSupabase,
      );

      if (response.isSuccess) {
        _logger.paperAction('update_paper_status_success', id, context: {
          'newStatus': status,
          'reviewedAt': response.data!.reviewedAt?.toIso8601String(),
        });
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to update paper status');
      }
    } catch (e, stackTrace) {
      _logger.paperError('update_paper_status', id, e);
      rethrow;
    }
  }

  @override
  Future<void> saveRejectionHistory({
    required String paperId,
    required String rejectionReason,
    required String rejectedBy,
    required DateTime rejectedAt,
  }) async {
    try {
      _logger.info('Saving rejection history', category: LogCategory.paper, context: {
        'paperId': paperId,
        'rejectedBy': rejectedBy,
      });

      // Get current rejection count for this paper to determine revision number
      int revisionNumber = 1;

      try {
        final historyResponse = await _apiClient.select<Map<String, dynamic>>(
          table: 'paper_rejection_history',
          fromJson: (json) => json,
          filters: {'paper_id': paperId},
          orderBy: 'revision_number',
          ascending: false,
        );

        if (historyResponse.isSuccess && historyResponse.data != null && historyResponse.data!.isNotEmpty) {
          revisionNumber = (historyResponse.data!.first['revision_number'] as int) + 1;
        }
      } catch (e) {
        _logger.warning('Could not get revision number, using 1', category: LogCategory.paper);
      }

      final data = {
        'paper_id': paperId,
        'rejection_reason': rejectionReason,
        'rejected_by': rejectedBy,
        'rejected_at': rejectedAt.toIso8601String(),
        'revision_number': revisionNumber,
      };

      final response = await _apiClient.insert<Map<String, dynamic>>(
        table: 'paper_rejection_history',
        data: data,
        fromJson: (json) => json,
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to save rejection history');
      }

      _logger.info('Rejection history saved', category: LogCategory.paper, context: {
        'paperId': paperId,
        'revisionNumber': revisionNumber,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to save rejection history',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRejectionHistory(String paperId) async {
    try {
      _logger.info('Fetching rejection history', category: LogCategory.paper, context: {
        'paperId': paperId,
      });

      final response = await _apiClient.select<Map<String, dynamic>>(
        table: 'paper_rejection_history',
        fromJson: (json) => json,
        filters: {'paper_id': paperId},
        orderBy: 'revision_number',
        ascending: true,
      );

      if (response.isSuccess && response.data != null) {
        _logger.info('Rejection history fetched', category: LogCategory.paper, context: {
          'paperId': paperId,
          'historyCount': response.data!.length,
        });
        return response.data!;
      }

      return [];
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch rejection history',
          category: LogCategory.paper,
          error: e,
          stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Future<QuestionPaperModel?> getPaperById(String id) async {
    try {
      final response = await _apiClient.selectSingle<QuestionPaperModel>(
        table: _viewName,
        fromJson: QuestionPaperModel.fromSupabase,
        filters: {'id': id},
      );

      if (response.isSuccess) {
        return response.data;
      } else if (response.errorType == ApiErrorType.notFound) {
        return null;
      } else {
        throw Exception(response.message ?? 'Failed to get paper');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch paper by ID',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deletePaper(String id) async {
    try {
      _logger.paperAction('delete_paper_started', id);

      final response = await _apiClient.delete(
        table: _tableName,
        filters: {'id': id},
      );

      if (response.isSuccess) {
        _logger.paperAction('delete_paper_success', id);
      } else {
        throw Exception(response.message ?? 'Failed to delete paper');
      }
    } catch (e, stackTrace) {
      _logger.paperError('delete_paper', id, e);
      rethrow;
    }
  }
}