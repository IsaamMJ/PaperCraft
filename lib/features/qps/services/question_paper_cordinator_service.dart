import 'package:papercraft/core/services/logger.dart';

import '../../authentication/data/datasources/local_storage_data_source.dart';
import '../data/models/question_paper_model.dart';
import '../services/question_paper_storage_service.dart';
import 'cloud_service.dart';

// Result classes for better error handling
class QuestionPaperResult<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;

  QuestionPaperResult.success(this.data)
      : success = true, error = null, errorCode = null;

  QuestionPaperResult.failure(this.error, {this.errorCode})
      : success = false, data = null;
}

class QuestionPaperCoordinatorService {
  final QuestionPaperStorageService _localService = QuestionPaperStorageService();
  final QuestionPaperCloudService _cloudService = QuestionPaperCloudService();
  final LocalStorageDataSource _localStorage;

  QuestionPaperCoordinatorService(this._localStorage);

  // Save as draft (local storage only)
  Future<QuestionPaperResult<QuestionPaperModel>> saveDraft(QuestionPaperModel questionPaper) async {
    try {
      LoggingService.debug('Saving question paper as draft: ${questionPaper.title}');

      final updatedPaper = questionPaper.copyWith(
        status: 'draft',
        modifiedAt: DateTime.now(),
      );

      final success = await _localService.saveQuestionPaper(updatedPaper);

      if (success) {
        LoggingService.debug('Draft saved successfully');
        return QuestionPaperResult.success(updatedPaper);
      } else {
        return QuestionPaperResult.failure('Failed to save draft locally');
      }
    } catch (e) {
      LoggingService.error('Error saving draft: $e');
      return QuestionPaperResult.failure('Error saving draft: $e');
    }
  }

  // Submit for approval (move from local to cloud)
  Future<QuestionPaperResult<String>> submitForApproval(QuestionPaperModel questionPaper) async {
    try {
      LoggingService.debug('Submitting question paper for approval: ${questionPaper.title}');

      // Get user context
      final tenantId = await _localStorage.getTenantId();
      final userId = await _localStorage.getUserId();

      if (tenantId == null || userId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated. Please log in again.',
            errorCode: 'AUTH_ERROR'
        );
      }

      // Submit to cloud
      final success = await _cloudService.submitQuestionPaper(
        questionPaper: questionPaper,
        tenantId: tenantId,
        userId: userId,
      );

      if (success) {
        // Remove from local storage after successful submission
        await _localService.deleteQuestionPaper(questionPaper.id, 'draft');

        LoggingService.debug('Question paper submitted successfully');
        return QuestionPaperResult.success('Question paper submitted for approval');
      } else {
        return QuestionPaperResult.failure('Failed to submit question paper to server');
      }
    } catch (e) {
      LoggingService.error('Error submitting question paper: $e');
      return QuestionPaperResult.failure('Error submitting question paper: $e');
    }
  }

  // Get drafts (from local storage)
  Future<QuestionPaperResult<List<QuestionPaperModel>>> getDrafts() async {
    try {
      LoggingService.debug('Getting drafts from local storage');

      final drafts = await _localService.getQuestionPapersByStatus('draft');
      return QuestionPaperResult.success(drafts);
    } catch (e) {
      LoggingService.error('Error getting drafts: $e');
      return QuestionPaperResult.failure('Error getting drafts: $e');
    }
  }

  // Get submitted papers for current user (from cloud)
  Future<QuestionPaperResult<List<QuestionPaperCloudModel>>> getUserSubmissions() async {
    try {
      LoggingService.debug('Getting user submissions from cloud');

      final tenantId = await _localStorage.getTenantId();
      final userId = await _localStorage.getUserId();

      if (tenantId == null || userId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated',
            errorCode: 'AUTH_ERROR'
        );
      }


      final submissions = await _cloudService.getUserQuestionPapers(
        userId: userId,
        tenantId: tenantId,
      );

      return QuestionPaperResult.success(submissions);
    } catch (e) {
      LoggingService.error('Error getting user submissions: $e');
      return QuestionPaperResult.failure('Error getting user submissions: $e');
    }
  }



  // Get papers for admin review (from cloud)
  Future<QuestionPaperResult<List<QuestionPaperCloudModel>>> getPapersForReview() async {
    try {
      LoggingService.debug('Getting papers for admin review');

      final tenantId = await _localStorage.getTenantId();
      final userRole = await _localStorage.getUserRole();

      if (tenantId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated',
            errorCode: 'AUTH_ERROR'
        );
      }

      // Check if user has admin privileges
      if (userRole != 'admin' && userRole != 'super_admin') {
        return QuestionPaperResult.failure(
            'Access denied. Admin privileges required.',
            errorCode: 'ACCESS_DENIED'
        );
      }

      final submissions = await _cloudService.getQuestionPapersByStatus(
        status: 'submitted',
        tenantId: tenantId,
      );

      return QuestionPaperResult.success(submissions);
    } catch (e) {
      LoggingService.error('Error getting papers for review: $e');
      return QuestionPaperResult.failure('Error getting papers for review: $e');
    }
  }

  // Admin: Approve question paper
  Future<QuestionPaperResult<String>> approveQuestionPaper(String questionPaperId) async {
    try {
      LoggingService.debug('Approving question paper: $questionPaperId');

      final userId = await _localStorage.getUserId();
      final userRole = await _localStorage.getUserRole();

      // Verify admin privileges
      if (userRole != 'admin' && userRole != 'super_admin') {
        return QuestionPaperResult.failure(
            'Access denied. Admin privileges required.',
            errorCode: 'ACCESS_DENIED'
        );
      }

      final success = await _cloudService.updateQuestionPaperStatus(
        questionPaperId: questionPaperId,
        newStatus: 'approved',
        reviewerId: userId,
      );

      if (success) {
        LoggingService.debug('Question paper approved successfully');
        return QuestionPaperResult.success('Question paper approved successfully');
      } else {
        return QuestionPaperResult.failure('Failed to approve question paper');
      }
    } catch (e) {
      LoggingService.error('Error approving question paper: $e');
      return QuestionPaperResult.failure('Error approving question paper: $e');
    }
  }

  // Admin: Reject question paper
  Future<QuestionPaperResult<String>> rejectQuestionPaper(
      String questionPaperId,
      String rejectionReason
      ) async {
    try {
      LoggingService.debug('Rejecting question paper: $questionPaperId');

      final userId = await _localStorage.getUserId();
      final userRole = await _localStorage.getUserRole();

      // Verify admin privileges
      if (userRole != 'admin' && userRole != 'super_admin') {
        return QuestionPaperResult.failure(
            'Access denied. Admin privileges required.',
            errorCode: 'ACCESS_DENIED'
        );
      }

      final success = await _cloudService.updateQuestionPaperStatus(
        questionPaperId: questionPaperId,
        newStatus: 'rejected',
        rejectionReason: rejectionReason,
        reviewerId: userId,
      );

      if (success) {
        LoggingService.debug('Question paper rejected successfully');
        return QuestionPaperResult.success('Question paper rejected with feedback');
      } else {
        return QuestionPaperResult.failure('Failed to reject question paper');
      }
    } catch (e) {
      LoggingService.error('Error rejecting question paper: $e');
      return QuestionPaperResult.failure('Error rejecting question paper: $e');
    }
  }

  // User: Pull rejected paper for editing
  Future<QuestionPaperResult<QuestionPaperModel>> pullForEditing(String questionPaperId) async {
    try {
      LoggingService.debug('Pulling rejected paper for editing: $questionPaperId');

      // Get the question paper from cloud
      final cloudPaper = await _cloudService.getQuestionPaperById(questionPaperId);

      if (cloudPaper == null) {
        return QuestionPaperResult.failure('Question paper not found');
      }

      // Check if paper is rejected and belongs to current user
      final userId = await _localStorage.getUserId();
      if (cloudPaper.userId != userId) {
        return QuestionPaperResult.failure(
            'Access denied. You can only edit your own question papers.',
            errorCode: 'ACCESS_DENIED'
        );
      }

      if (cloudPaper.status != 'rejected') {
        return QuestionPaperResult.failure(
            'Only rejected question papers can be pulled for editing.',
            errorCode: 'INVALID_STATUS'
        );
      }

      // Convert to local model and create new instance with new ID and status
      final localModel = cloudPaper.toLocalModel();

      // Create a new QuestionPaperModel with updated properties
      // Note: Since we can't modify id directly, we create a completely new instance
      final editableModel = QuestionPaperModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // New local ID
        title: localModel.title,
        subject: localModel.subject,
        examType: localModel.examType,
        createdBy: localModel.createdBy,
        createdAt: localModel.createdAt,
        modifiedAt: DateTime.now(),
        status: 'draft',
        examTypeEntity: localModel.examTypeEntity,
        questions: localModel.questions,
        selectedSubjects: localModel.selectedSubjects,
        rejectionReason: localModel.rejectionReason, // Keep rejection reason for reference
        approvedBy: localModel.approvedBy,
        approvedAt: localModel.approvedAt,
      );

      final success = await _localService.saveQuestionPaper(editableModel);

      if (success) {
        LoggingService.debug('Question paper pulled for editing successfully');
        return QuestionPaperResult.success(editableModel);
      } else {
        return QuestionPaperResult.failure('Failed to save question paper locally');
      }
    } catch (e) {
      LoggingService.error('Error pulling question paper for editing: $e');
      return QuestionPaperResult.failure('Error pulling question paper for editing: $e');
    }
  }

  // Get approved papers (for printing/use)
  Future<QuestionPaperResult<List<QuestionPaperCloudModel>>> getApprovedPapers() async {
    try {
      LoggingService.debug('Getting approved question papers');

      final tenantId = await _localStorage.getTenantId();

      if (tenantId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated',
            errorCode: 'AUTH_ERROR'
        );
      }

      final approvedPapers = await _cloudService.getQuestionPapersByStatus(
        status: 'approved',
        tenantId: tenantId,
      );

      return QuestionPaperResult.success(approvedPapers);
    } catch (e) {
      LoggingService.error('Error getting approved papers: $e');
      return QuestionPaperResult.failure('Error getting approved papers: $e');
    }
  }

  // Search functionality
  Future<QuestionPaperResult<List<QuestionPaperCloudModel>>> searchQuestionPapers({
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  }) async {
    try {
      LoggingService.debug('Searching question papers');

      final tenantId = await _localStorage.getTenantId();

      if (tenantId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated',
            errorCode: 'AUTH_ERROR'
        );
      }

      final searchResults = await _cloudService.searchQuestionPapers(
        tenantId: tenantId,
        title: title,
        subject: subject,
        status: status,
        createdBy: createdBy,
      );

      return QuestionPaperResult.success(searchResults);
    } catch (e) {
      LoggingService.error('Error searching question papers: $e');
      return QuestionPaperResult.failure('Error searching question papers: $e');
    }
  }

  // Get statistics for dashboard
  Future<QuestionPaperResult<QuestionPaperStats>> getStatistics() async {
    try {
      LoggingService.debug('Getting question paper statistics');

      final tenantId = await _localStorage.getTenantId();
      final userId = await _localStorage.getUserId();

      if (tenantId == null || userId == null) {
        return QuestionPaperResult.failure(
            'User not authenticated',
            errorCode: 'AUTH_ERROR'
        );
      }

      // Get cloud stats
      final cloudStats = await _cloudService.getQuestionPaperStats(tenantId);

      // Get local drafts count
      final localDrafts = await _localService.getQuestionPapersByStatus('draft');

      final stats = QuestionPaperStats(
        totalDrafts: localDrafts.length,
        totalSubmitted: cloudStats['submitted'] ?? 0,
        totalApproved: cloudStats['approved'] ?? 0,
        totalRejected: cloudStats['rejected'] ?? 0,
      );

      return QuestionPaperResult.success(stats);
    } catch (e) {
      LoggingService.error('Error getting statistics: $e');
      return QuestionPaperResult.failure('Error getting statistics: $e');
    }
  }

  // Sync status updates (call this periodically or on app resume)
  Future<QuestionPaperResult<List<QuestionPaperCloudModel>>> syncStatusUpdates() async {
    try {
      LoggingService.debug('Syncing question paper status updates');

      final result = await getUserSubmissions();
      if (!result.success) {
        return result;
      }

      final submissions = result.data!;
      final statusUpdates = submissions.where((paper) =>
      paper.status == 'approved' || paper.status == 'rejected'
      ).toList();

      LoggingService.debug('Found ${statusUpdates.length} status updates');
      return QuestionPaperResult.success(statusUpdates);
    } catch (e) {
      LoggingService.error('Error syncing status updates: $e');
      return QuestionPaperResult.failure('Error syncing status updates: $e');
    }
  }

  // Delete draft (local only)
  Future<QuestionPaperResult<String>> deleteDraft(String draftId) async {
    try {
      LoggingService.debug('Deleting draft: $draftId');

      final success = await _localService.deleteQuestionPaper(draftId, 'draft');

      if (success) {
        return QuestionPaperResult.success('Draft deleted successfully');
      } else {
        return QuestionPaperResult.failure('Failed to delete draft');
      }
    } catch (e) {
      LoggingService.error('Error deleting draft: $e');
      return QuestionPaperResult.failure('Error deleting draft: $e');
    }
  }

  // Admin: Delete submitted/approved/rejected paper (cloud only)
  Future<QuestionPaperResult<String>> deleteQuestionPaper(String questionPaperId) async {
    try {
      LoggingService.debug('Deleting question paper: $questionPaperId');

      final userRole = await _localStorage.getUserRole();

      // Verify admin privileges
      if (userRole != 'admin' && userRole != 'super_admin') {
        return QuestionPaperResult.failure(
            'Access denied. Admin privileges required.',
            errorCode: 'ACCESS_DENIED'
        );
      }

      final success = await _cloudService.deleteQuestionPaper(questionPaperId);

      if (success) {
        return QuestionPaperResult.success('Question paper deleted successfully');
      } else {
        return QuestionPaperResult.failure('Failed to delete question paper');
      }
    } catch (e) {
      LoggingService.error('Error deleting question paper: $e');
      return QuestionPaperResult.failure('Error deleting question paper: $e');
    }
  }

  // Check user permissions
  Future<bool> hasAdminPermissions() async {
    try {
      final userRole = await _localStorage.getUserRole();
      return userRole == 'admin' || userRole == 'super_admin';
    } catch (e) {
      LoggingService.error('Error checking admin permissions: $e');
      return false;
    }
  }

  // Get user context
  Future<Map<String, String?>> getUserContext() async {
    try {
      return {
        'tenant_id': await _localStorage.getTenantId(),
        'user_id': await _localStorage.getUserId(),
        'full_name': await _localStorage.getFullName(),
        'user_role': await _localStorage.getUserRole(),
      };
    } catch (e) {
      LoggingService.error('Error getting user context: $e');
      return {
        'tenant_id': null,
        'user_id': null,
        'full_name': null,
        'user_role': null,
      };
    }
  }

  // Validate user session
  Future<bool> isValidSession() async {
    try {
      final tenantId = await _localStorage.getTenantId();
      final userId = await _localStorage.getUserId();
      return tenantId != null && userId != null;
    } catch (e) {
      LoggingService.error('Error validating session: $e');
      return false;
    }
  }

  // Clean up local data (call on logout)
  Future<QuestionPaperResult<String>> cleanupLocalData() async {
    try {
      LoggingService.debug('Cleaning up local question paper data');

      // Note: Implement cleanup logic based on your storage service
      // This might involve clearing drafts or syncing unsaved changes

      return QuestionPaperResult.success('Local data cleaned up successfully');
    } catch (e) {
      LoggingService.error('Error cleaning up local data: $e');
      return QuestionPaperResult.failure('Error cleaning up local data: $e');
    }
  }
}

// Statistics model
class QuestionPaperStats {
  final int totalDrafts;
  final int totalSubmitted;
  final int totalApproved;
  final int totalRejected;

  QuestionPaperStats({
    required this.totalDrafts,
    required this.totalSubmitted,
    required this.totalApproved,
    required this.totalRejected,
  });

  int get totalPapers => totalDrafts + totalSubmitted + totalApproved + totalRejected;

  Map<String, int> toMap() {
    return {
      'totalDrafts': totalDrafts,
      'totalSubmitted': totalSubmitted,
      'totalApproved': totalApproved,
      'totalRejected': totalRejected,
      'totalPapers': totalPapers,
    };
  }

  @override
  String toString() {
    return 'QuestionPaperStats(totalDrafts: $totalDrafts, totalSubmitted: $totalSubmitted, '
        'totalApproved: $totalApproved, totalRejected: $totalRejected, totalPapers: $totalPapers)';
  }
}

// Extension for QuestionPaperCloudModel (you'll need to implement this)
extension QuestionPaperCloudModelExtension on QuestionPaperCloudModel {
  QuestionPaperModel toLocalModel() {
    // Convert cloud model to local model
    // You'll need to implement this
    // based on your model structure
    throw UnimplementedError('toLocalModel() needs to be implemented based on your model structure');
  }
}