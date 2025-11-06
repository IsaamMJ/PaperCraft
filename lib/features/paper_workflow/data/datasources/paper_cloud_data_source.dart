// features/question_papers/data/datasources/paper_cloud_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/domain/models/paginated_result.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/network/models/api_response.dart';
import '../../../../core/infrastructure/cache/cache_service.dart';
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
  Future<PaginatedResult<QuestionPaperModel>> getApprovedPapersPaginated({
    required String tenantId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
  });
  Future<List<QuestionPaperModel>> getApprovedPapersByExamDateRange({
    required String tenantId,
    required DateTime fromDate,
    required DateTime toDate,
  });
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
  final CacheService _cache;
  static const String _tableName = 'question_papers';

  // Cache key prefixes
  static const String _cacheKeyApprovedPapers = 'approved_papers_';
  static const String _cacheKeyUserSubmissions = 'user_submissions_';
  static const String _cacheKeyPapersForReview = 'papers_for_review_';
  static const String _cacheKeyAllPapersAdmin = 'all_papers_admin_';

  PaperCloudDataSourceImpl(this._apiClient, this._logger, this._cache);

  @override
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper) async {
    try {
      _logger.paperAction('submit_paper_started', paper.id, context: {
        'title': paper.title,
        'subjectId': paper.subjectId,
        'gradeId': paper.gradeId,
        'academicYear': paper.academicYear,
        'tenantId': paper.tenantId,
        'userId': paper.userId,
      });

      final data = paper.toSupabaseMap();

      // OPTIMIZATION: Use upsert instead of checking if exists then insert/update
      // This is a single database operation instead of 2 queries (N+1 problem fixed)
      final response = await _apiClient.upsert<QuestionPaperModel>(
        table: _tableName,
        data: data,
        fromJson: QuestionPaperModel.fromSupabase,
      );

      if (response.isSuccess) {
        // OPTIMIZATION: Invalidate cache when paper is submitted
        _cache.remove('$_cacheKeyApprovedPapers${paper.tenantId}');
        _cache.remove('$_cacheKeyUserSubmissions${paper.tenantId}_${paper.userId}');
        _cache.remove('$_cacheKeyPapersForReview${paper.tenantId}');
        _cache.remove('$_cacheKeyAllPapersAdmin${paper.tenantId}');

        _logger.paperAction('submit_paper_success', response.data!.id, context: {
          'title': paper.title,
          'submittedAt': response.data!.submittedAt?.toIso8601String(),
        });
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to submit paper');
      }
    } catch (e, _) {
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

      // Use direct Supabase query to include subject name joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId)
          .order('submitted_at', ascending: false);

      final response = await queryBuilder;

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      _logger.debug('Fetched all papers for admin',
          category: LogCategory.storage,
          context: {'tenantId': tenantId, 'itemCount': items.length});

      return items;
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
      // OPTIMIZATION: Check cache first to avoid database query
      final cacheKey = '$_cacheKeyApprovedPapers$tenantId';
      final cachedData = _cache.get<List<QuestionPaperModel>>(cacheKey);
      if (cachedData != null) {
        _logger.debug('Cache HIT: getApprovedPapers',
            category: LogCategory.storage,
            context: {'tenantId': tenantId, 'itemCount': cachedData.length});
        return cachedData;
      }

      // Use direct Supabase query to include subject name joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId)
          .eq('status', 'approved')
          .order('reviewed_at', ascending: false);

      final response = await queryBuilder;

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      // OPTIMIZATION: Cache the result for 5 minutes
      _cache.set(cacheKey, items, duration: const Duration(minutes: 5));
      _logger.debug('Cached: getApprovedPapers',
          category: LogCategory.storage,
          context: {'tenantId': tenantId, 'itemCount': items.length});
      return items;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch approved papers',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<PaginatedResult<QuestionPaperModel>> getApprovedPapersPaginated({
    required String tenantId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
  }) async {
    try {
      // Calculate range for pagination
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      // Build query builder with all filters and subject joins
      var queryBuilder = Supabase.instance.client.from(_tableName).select(
          'id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)');

      queryBuilder = queryBuilder
          .eq('tenant_id', tenantId)
          .eq('status', 'approved');

      // Apply optional filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('title', '%$searchQuery%');
      }
      if (subjectFilter != null && subjectFilter.isNotEmpty) {
        queryBuilder = queryBuilder.eq('subject_id', subjectFilter);
      }
      if (gradeFilter != null && gradeFilter.isNotEmpty) {
        queryBuilder = queryBuilder.eq('grade_id', gradeFilter);
      }

      // Execute paginated query
      final response = await queryBuilder
          .order('reviewed_at', ascending: false)
          .range(from, to);

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      // OPTIMIZATION: Build a matching filter list for count query to ensure accuracy
      var countBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('status', 'approved');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        countBuilder = countBuilder.ilike('title', '%$searchQuery%');
      }
      if (subjectFilter != null && subjectFilter.isNotEmpty) {
        countBuilder = countBuilder.eq('subject_id', subjectFilter);
      }
      if (gradeFilter != null && gradeFilter.isNotEmpty) {
        countBuilder = countBuilder.eq('grade_id', gradeFilter);
      }

      // Get count with exact same filters by using count method
      final countResponse = await countBuilder.count(CountOption.exact);
      final totalItems = countResponse.count;

      _logger.info('Fetched paginated approved papers', category: LogCategory.storage, context: {
        'page': page,
        'pageSize': pageSize,
        'totalItems': totalItems,
        'returnedItems': items.length,
      });

      return PaginatedResult.fromCount(
        items: items,
        currentPage: page,
        totalItems: totalItems,
        pageSize: pageSize,
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch paginated approved papers',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId) async {
    try {
      // Use direct Supabase query to include subject name joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .order('submitted_at', ascending: false);

      final response = await queryBuilder;

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      return items;
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
      // Use direct Supabase query to include subject name joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId)
          .eq('status', 'submitted')
          .order('submitted_at', ascending: false);

      final response = await queryBuilder;

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      return items;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch papers for review',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getApprovedPapersByExamDateRange({
    required String tenantId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      _logger.debug('Fetching approved papers by exam date range',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'fromDate': fromDate.toIso8601String(),
            'toDate': toDate.toIso8601String(),
          });

      // Build query using Supabase client directly with subject joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,exam_date,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId)
          .eq('status', 'approved')
          .gte('exam_date', fromDate.toIso8601String())
          .lte('exam_date', toDate.toIso8601String())
          .order('exam_date', ascending: true);

      final response = await queryBuilder;

      // Parse response data
      final items = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      _logger.info('Fetched approved papers by exam date range',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'fromDate': fromDate.toIso8601String(),
            'toDate': toDate.toIso8601String(),
            'itemCount': items.length,
          });

      return items;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch approved papers by exam date range',
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
      // Build query with subject joins
      var queryBuilder = Supabase.instance.client
          .from(_tableName)
          .select('id,title,subject_id,grade_id,academic_year,created_at,updated_at,status,tenant_id,user_id,submitted_at,reviewed_at,reviewed_by,rejection_reason,exam_type,questions,subjects(catalog_subject_id,subject_catalog(subject_name)),grades(grade_number)')
          .eq('tenant_id', tenantId);

      if (status != null && status.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', status);
      }

      if (userId != null && userId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('user_id', userId);
      }

      // Execute query with order (don't reassign queryBuilder after order())
      final response = await queryBuilder.order('created_at', ascending: false);

      // Parse response data
      var results = (response as List)
          .map((json) => QuestionPaperModel.fromSupabase(json as Map<String, dynamic>))
          .toList();

      // Filter by title if provided (client-side filtering after database query)
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
    } catch (e, _) {
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
        table: _tableName,
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
    } catch (e, _) {
      _logger.paperError('delete_paper', id, e);
      rethrow;
    }
  }
}