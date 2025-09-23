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
  Future<List<QuestionPaperModel>> searchPapers(String tenantId, {
    String? title,
    String? subject,
    String? status,
    String? userId,
  });
}

class PaperCloudDataSourceImpl implements PaperCloudDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'question_papers';

  PaperCloudDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper) async {
    try {
      _logger.paperAction('submit_paper_started', paper.id, context: {
        'title': paper.title,
        'subject': paper.subject,
        'examType': paper.examType,
        'tenantId': paper.tenantId,
        'userId': paper.userId,
        'storageType': 'supabase_cloud',
      });

      final data = paper.toSupabaseMap();

      final response = await _apiClient.insert<QuestionPaperModel>(
        table: _tableName,
        data: data,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
      );

      if (response.isSuccess) {
        _logger.paperAction('submit_paper_success', paper.id, context: {
          'title': paper.title,
          'subject': paper.subject,
          'submittedAt': response.data!.submittedAt?.toIso8601String(),
          'storageType': 'supabase_cloud',
        });
        return response.data!;
      } else {
        _logger.paperError('submit_paper', paper.id,
            Exception('API Error: ${response.message}'),
            context: {
              'title': paper.title,
              'subject': paper.subject,
              'apiErrorType': response.errorType?.toString(),
              'apiMessage': response.message,
              'storageType': 'supabase_cloud',
            }
        );
        throw Exception(response.message ?? 'Failed to submit paper');
      }
    } catch (e, stackTrace) {
      _logger.paperError('submit_paper', paper.id, e, context: {
        'title': paper.title,
        'subject': paper.subject,
        'storageType': 'supabase_cloud',
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }


  @override
  Future<List<QuestionPaperModel>> getAllPapersForAdmin(String tenantId) async {
    try {
      _logger.debug('Fetching all papers for admin from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
      });

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
        filters: {
          'tenant_id': tenantId,
          // No status filter - get ALL papers (submitted, approved, rejected)
        },
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get papers for admin');
      }
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getApprovedPapers(String tenantId) async {
    try {
      _logger.debug('Fetching approved papers from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'status': 'approved',
      });

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
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
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId) async {
    try {
      _logger.debug('Fetching user submissions from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'userId': userId,
      });

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
        filters: {
          'tenant_id': tenantId,
          'user_id': userId,
        },
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        _logger.info('User submissions fetched successfully from Supabase',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'userId': userId,
              'submissionsCount': response.data!.length,
              'storageType': 'supabase_cloud',
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to fetch user submissions from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'userId': userId,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'storageType': 'supabase_cloud',
          },
        );
        throw Exception(response.message ?? 'Failed to get user submissions');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch user submissions from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'userId': userId,
          'storageType': 'supabase_cloud',
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId) async {
    try {
      _logger.debug('Fetching papers for review from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'status': 'submitted',
      });

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
        filters: {
          'tenant_id': tenantId,
          'status': 'submitted',
        },
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        _logger.info('Papers for review fetched successfully from Supabase',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'papersCount': response.data!.length,
              'storageType': 'supabase_cloud',
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to fetch papers for review from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'storageType': 'supabase_cloud',
          },
        );
        throw Exception(response.message ?? 'Failed to get papers for review');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch papers for review from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'storageType': 'supabase_cloud',
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<QuestionPaperModel> updatePaperStatus(String id, String status, {String? reason, String? reviewerId}) async {
    try {
      _logger.paperAction('update_paper_status_started', id, context: {
        'newStatus': status,
        'reason': reason,
        'reviewerId': reviewerId,
        'storageType': 'supabase_cloud',
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
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
      );

      if (response.isSuccess) {
        _logger.paperAction('update_paper_status_success', id, context: {
          'newStatus': status,
          'reason': reason,
          'reviewerId': reviewerId,
          'reviewedAt': response.data!.reviewedAt?.toIso8601String(),
          'storageType': 'supabase_cloud',
        });
        return response.data!;
      } else {
        _logger.paperError('update_paper_status', id,
            Exception('API Error: ${response.message}'),
            context: {
              'newStatus': status,
              'reason': reason,
              'reviewerId': reviewerId,
              'apiErrorType': response.errorType?.toString(),
              'apiMessage': response.message,
              'storageType': 'supabase_cloud',
            }
        );
        throw Exception(response.message ?? 'Failed to update paper status');
      }
    } catch (e, stackTrace) {
      _logger.paperError('update_paper_status', id, e, context: {
        'newStatus': status,
        'reason': reason,
        'reviewerId': reviewerId,
        'storageType': 'supabase_cloud',
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<QuestionPaperModel?> getPaperById(String id) async {
    try {
      _logger.debug('Fetching paper by ID from Supabase', category: LogCategory.storage, context: {
        'paperId': id,
      });

      final response = await _apiClient.selectSingle<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
        filters: {'id': id},
      );

      if (response.isSuccess) {
        if (response.data != null) {
          _logger.debug('Paper found in Supabase', category: LogCategory.storage, context: {
            'paperId': id,
            'title': response.data!.title,
            'status': response.data!.status.value,
            'storageType': 'supabase_cloud',
          });
        } else {
          _logger.debug('Paper not found in Supabase', category: LogCategory.storage, context: {
            'paperId': id,
            'reason': 'not_exists',
            'storageType': 'supabase_cloud',
          });
        }
        return response.data;
      } else {
        // For not found errors, return null instead of throwing
        if (response.errorType == ApiErrorType.notFound) {
          _logger.debug('Paper not found in Supabase', category: LogCategory.storage, context: {
            'paperId': id,
            'reason': 'api_not_found',
            'storageType': 'supabase_cloud',
          });
          return null;
        }

        _logger.error('Failed to fetch paper by ID from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'paperId': id,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'storageType': 'supabase_cloud',
          },
        );
        throw Exception(response.message ?? 'Failed to get paper by ID');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch paper by ID from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'paperId': id,
          'storageType': 'supabase_cloud',
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<void> deletePaper(String id) async {
    try {
      _logger.paperAction('delete_paper_started', id, context: {
        'storageType': 'supabase_cloud',
      });

      final response = await _apiClient.delete(
        table: _tableName,
        filters: {'id': id},
      );

      if (response.isSuccess) {
        _logger.paperAction('delete_paper_success', id, context: {
          'storageType': 'supabase_cloud',
        });
      } else {
        _logger.paperError('delete_paper', id,
            Exception('API Error: ${response.message}'),
            context: {
              'apiErrorType': response.errorType?.toString(),
              'apiMessage': response.message,
              'storageType': 'supabase_cloud',
            }
        );
        throw Exception(response.message ?? 'Failed to delete paper');
      }
    } catch (e, stackTrace) {
      _logger.paperError('delete_paper', id, e, context: {
        'storageType': 'supabase_cloud',
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> searchPapers(String tenantId, {
    String? title,
    String? subject,
    String? status,
    String? userId,
  }) async {
    try {
      _logger.debug('Searching papers in Supabase with filters', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'hasTitleFilter': title != null,
        'hasSubjectFilter': subject != null,
        'hasStatusFilter': status != null,
        'hasUserIdFilter': userId != null,
        'title': title,
        'subject': subject,
        'status': status,
        'userId': userId,
      });

      final filters = <String, dynamic>{
        'tenant_id': tenantId,
      };

      // Add optional filters
      if (status != null) filters['status'] = status;
      if (userId != null) filters['user_id'] = userId;
      if (title != null) filters['title'] = '%$title%'; // For ILIKE search
      if (subject != null) filters['subject'] = '%$subject%'; // For ILIKE search

      final response = await _apiClient.select<QuestionPaperModel>(
        table: _tableName,
        fromJson: (json) => QuestionPaperModel.fromSupabase(json),
        filters: filters,
        orderBy: 'submitted_at',
        ascending: false,
      );

      if (response.isSuccess) {
        _logger.info('Paper search completed successfully in Supabase',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'resultsCount': response.data!.length,
              'filters': {
                'title': title,
                'subject': subject,
                'status': status,
                'userId': userId,
              },
              'storageType': 'supabase_cloud',
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to search papers in Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'searchFilters': {
              'title': title,
              'subject': subject,
              'status': status,
              'userId': userId,
            },
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'storageType': 'supabase_cloud',
          },
        );
        throw Exception(response.message ?? 'Failed to search papers');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to search papers in Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'searchFilters': {
            'title': title,
            'subject': subject,
            'status': status,
            'userId': userId,
          },
          'storageType': 'supabase_cloud',
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }
}