import 'package:flutter/foundation.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../models/reviewer_assignment_model.dart';

abstract class ReviewerAssignmentDataSource {
  Future<List<ReviewerAssignmentModel>> getReviewerAssignments(String tenantId);
  Future<ReviewerAssignmentModel> getReviewerAssignment(String assignmentId);
  Future<ReviewerAssignmentModel> createReviewerAssignment({
    required String tenantId,
    required String reviewerId,
    required int gradeMin,
    required int gradeMax,
  });
  Future<ReviewerAssignmentModel> updateReviewerAssignment({
    required String assignmentId,
    required int gradeMin,
    required int gradeMax,
  });
  Future<void> deleteReviewerAssignment(String assignmentId);
}

class ReviewerAssignmentDataSourceImpl implements ReviewerAssignmentDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'reviewer_grade_assignments';

  ReviewerAssignmentDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<ReviewerAssignmentModel>> getReviewerAssignments(String tenantId) async {
    try {
      debugPrint('[DEBUG DS] Fetching reviewer assignments for tenant: $tenantId');
      _logger.debug('Fetching reviewer assignments for tenant',
          category: LogCategory.auth,
          context: {'tenantId': tenantId});

      final response = await _apiClient.select<ReviewerAssignmentModel>(
        table: _tableName,
        fromJson: ReviewerAssignmentModel.fromJson,
        filters: {'tenant_id': tenantId},
        orderBy: 'created_at',
      );

      if (!response.isSuccess) {
        throw Exception(response.message ?? 'Failed to fetch reviewer assignments');
      }

      debugPrint('[DEBUG DS] Fetched ${response.data?.length ?? 0} reviewer assignments');
      return response.data ?? [];
    } catch (e, stackTrace) {
      debugPrint('[DEBUG DS] Error fetching assignments: $e');
      _logger.error('Failed to fetch reviewer assignments',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ReviewerAssignmentModel> getReviewerAssignment(String assignmentId) async {
    try {
      _logger.debug('Fetching reviewer assignment',
          category: LogCategory.auth,
          context: {'assignmentId': assignmentId});

      final response = await _apiClient.selectSingle<ReviewerAssignmentModel>(
        table: _tableName,
        fromJson: ReviewerAssignmentModel.fromJson,
        filters: {'id': assignmentId},
      );

      if (!response.isSuccess || response.data == null) {
        throw Exception('Reviewer assignment not found');
      }

      return response.data!;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ReviewerAssignmentModel> createReviewerAssignment({
    required String tenantId,
    required String reviewerId,
    required int gradeMin,
    required int gradeMax,
  }) async {
    try {
      debugPrint('[DEBUG DS] Creating reviewer assignment: reviewerId=$reviewerId, grades=$gradeMin-$gradeMax');
      _logger.info('Creating reviewer assignment',
          category: LogCategory.auth,
          context: {
            'tenantId': tenantId,
            'reviewerId': reviewerId,
            'gradeMin': gradeMin,
            'gradeMax': gradeMax,
          });

      final response = await _apiClient.insert<ReviewerAssignmentModel>(
        table: _tableName,
        data: {
          'tenant_id': tenantId,
          'reviewer_id': reviewerId,
          'grade_min': gradeMin,
          'grade_max': gradeMax,
        },
        fromJson: ReviewerAssignmentModel.fromJson,
      );

      if (!response.isSuccess || response.data == null) {
        throw Exception(response.message ?? 'Failed to create reviewer assignment');
      }

      debugPrint('[DEBUG DS] Assignment created successfully: ${response.data?.id}');
      _logger.info('Reviewer assignment created successfully',
          category: LogCategory.auth);

      return response.data!;
    } catch (e, stackTrace) {
      debugPrint('[DEBUG DS] Error creating assignment: $e');
      _logger.error('Failed to create reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ReviewerAssignmentModel> updateReviewerAssignment({
    required String assignmentId,
    required int gradeMin,
    required int gradeMax,
  }) async {
    try {
      debugPrint('[DEBUG DS] Updating reviewer assignment: assignmentId=$assignmentId, grades=$gradeMin-$gradeMax');
      _logger.info('Updating reviewer assignment',
          category: LogCategory.auth,
          context: {
            'assignmentId': assignmentId,
            'gradeMin': gradeMin,
            'gradeMax': gradeMax,
          });

      final supabase = await _getSupabaseClient();
      await supabase
          .from(_tableName)
          .update({'grade_min': gradeMin, 'grade_max': gradeMax})
          .eq('id', assignmentId);

      final updated = await getReviewerAssignment(assignmentId);
      debugPrint('[DEBUG DS] Assignment updated successfully');
      _logger.info('Reviewer assignment updated successfully',
          category: LogCategory.auth);

      return updated;
    } catch (e, stackTrace) {
      debugPrint('[DEBUG DS] Error updating assignment: $e');
      _logger.error('Failed to update reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteReviewerAssignment(String assignmentId) async {
    try {
      debugPrint('[DEBUG DS] Deleting reviewer assignment: assignmentId=$assignmentId');
      _logger.info('Deleting reviewer assignment',
          category: LogCategory.auth,
          context: {'assignmentId': assignmentId});

      final supabase = await _getSupabaseClient();
      await supabase.from(_tableName).delete().eq('id', assignmentId);

      debugPrint('[DEBUG DS] Assignment deleted successfully');
      _logger.info('Reviewer assignment deleted successfully',
          category: LogCategory.auth);
    } catch (e, stackTrace) {
      debugPrint('[DEBUG DS] Error deleting assignment: $e');
      _logger.error('Failed to delete reviewer assignment',
          category: LogCategory.auth,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<dynamic> _getSupabaseClient() async {
    // This is a placeholder - in real implementation, get from ApiClient
    // For now, we'll use the RPC approach in the repository layer
    throw UnimplementedError('Use ApiClient methods instead');
  }
}
