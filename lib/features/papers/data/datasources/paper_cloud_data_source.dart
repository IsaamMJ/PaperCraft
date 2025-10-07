// features/question_papers/data/datasources/paper_cloud_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/network/models/api_response.dart';
import '../models/question_paper_model.dart';

abstract class PaperCloudDataSource {
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper);
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId);
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId);
  Future<QuestionPaperModel> updatePaperStatus(String id, String status, {String? reason, String? reviewerId});
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

      final response = await _apiClient.insert<QuestionPaperModel>(
        table: _tableName,
        data: data,
        fromJson: QuestionPaperModel.fromSupabase,
      );

      if (response.isSuccess) {
        _logger.paperAction('submit_paper_success', response.data!.id, context: {
          'title': paper.title,
          'submittedAt': response.data!.submittedAt?.toIso8601String(),
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
      {String? reason, String? reviewerId}
      ) async {
    try {
      _logger.paperAction('update_paper_status_started', id, context: {
        'newStatus': status,
        'reason': reason,
        'reviewerId': reviewerId,
      });

      final updateData = <String, dynamic>{
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
      };

      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }

      if (reviewerId != null) {
        updateData['reviewed_by'] = reviewerId;
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