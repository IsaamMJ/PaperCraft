import 'package:papercraft/core/services/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../authentication/data/datasources/local_storage_data_source.dart';
import '../data/models/question_paper_model.dart';
import '../domain/entities/exam_type_entity.dart';
import '../domain/entities/subject_entity.dart';
import '../presentation/widgets/question_input_widget.dart';

class QuestionPaperCloudService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalStorageDataSource _localStorageDataSource = LocalStorageDataSourceImpl();
  static const String _tableName = 'question_papers';

  // Helper method to get current user data from SharedPreferences
  Future<Map<String, String?>> _getCurrentUserData() async {
    try {
      final results = await Future.wait([
        _localStorageDataSource.getTenantId(),
        _localStorageDataSource.getUserId(),
        _localStorageDataSource.getUserRole(),
      ]);

      return {
        'tenantId': results[0],
        'userId': results[1],
        'userRole': results[2],
      };
    } catch (e) {
      LoggingService.error('Error getting current user data: $e');
      return {
        'tenantId': null,
        'userId': null,
        'userRole': null,
      };
    }
  }

  // Submit question paper to cloud for approval
  Future<bool> submitQuestionPaper({
    required QuestionPaperModel questionPaper,
    String? tenantId,
    String? userId,
  }) async {
    try {
      // Get user data from SharedPreferences if not provided
      String? finalTenantId = tenantId;
      String? finalUserId = userId;

      if (finalTenantId == null || finalUserId == null) {
        final userData = await _getCurrentUserData();
        finalTenantId ??= userData['tenantId'];
        finalUserId ??= userData['userId'];

        if (finalTenantId == null || finalUserId == null) {
          LoggingService.error('Cannot submit question paper: Missing tenant ID or user ID');
          return false;
        }
      }

      LoggingService.debug('Submitting question paper: ${questionPaper.title}');
      LoggingService.debug('Tenant ID: $finalTenantId, User ID: $finalUserId');

      final data = {
        'tenant_id': finalTenantId,
        'user_id': finalUserId,
        'title': questionPaper.title,
        'subject': questionPaper.subject,
        'exam_type': questionPaper.examType,
        'questions': questionPaper.questions,
        'status': 'submitted',
        'metadata': {
          'exam_type_entity': questionPaper.examTypeEntity.toJson(),
          'selected_subjects': questionPaper.selectedSubjects.map((s) => s.toJson()).toList(),
          'created_locally_at': questionPaper.createdAt.toIso8601String(),
        },
      };

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      LoggingService.debug('Question paper submitted successfully: ${response['id']}');
      return true;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException submitting question paper: ${e.message}');
      LoggingService.error('Error code: ${e.code}');
      LoggingService.error('Details: ${e.details}');
      return false;
    } catch (e) {
      LoggingService.error('Error submitting question paper: $e');
      return false;
    }
  }

  // Get question papers by status for current user's tenant
  Future<List<QuestionPaperCloudModel>> getQuestionPapersByStatus({
    required String status,
    String? tenantId,
    String? userId, // Optional: filter by specific user
  }) async {
    try {
      // Get tenant ID from SharedPreferences if not provided
      String? finalTenantId = tenantId;
      if (finalTenantId == null) {
        final userData = await _getCurrentUserData();
        finalTenantId = userData['tenantId'];

        if (finalTenantId == null) {
          LoggingService.error('Cannot get question papers: Missing tenant ID');
          return [];
        }
      }

      LoggingService.debug('Fetching question papers with status: $status for tenant: $finalTenantId');

      var query = _supabase
          .from(_tableName)
          .select('''
            *,
            created_by_name:profiles!question_papers_user_id_fkey(full_name),
            reviewed_by_name:profiles!question_papers_reviewed_by_fkey(full_name)
          ''')
          .eq('tenant_id', finalTenantId)
          .eq('status', status);

      // Add user filter if specified
      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final response = await query.order('submitted_at', ascending: false);

      final questionPapers = response.map((data) {
        return QuestionPaperCloudModel.fromJson(data);
      }).toList();

      LoggingService.debug('Retrieved ${questionPapers.length} question papers');
      return questionPapers;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException getting question papers: ${e.message}');
      return [];
    } catch (e) {
      LoggingService.error('Error getting question papers: $e');
      return [];
    }
  }

  // Get all question papers for current user
  Future<List<QuestionPaperCloudModel>> getUserQuestionPapers({
    String? userId,
    String? tenantId,
  }) async {
    try {
      // Get user data from SharedPreferences if not provided
      String? finalUserId = userId;
      String? finalTenantId = tenantId;

      if (finalUserId == null || finalTenantId == null) {
        final userData = await _getCurrentUserData();
        finalUserId ??= userData['userId'];
        finalTenantId ??= userData['tenantId'];

        if (finalUserId == null || finalTenantId == null) {
          LoggingService.error('Cannot get user question papers: Missing user ID or tenant ID');
          return [];
        }
      }

      LoggingService.debug('Fetching all question papers for user: $finalUserId');

      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            created_by_name:profiles!question_papers_user_id_fkey(full_name),
            reviewed_by_name:profiles!question_papers_reviewed_by_fkey(full_name)
          ''')
          .eq('tenant_id', finalTenantId)
          .eq('user_id', finalUserId)
          .order('submitted_at', ascending: false);

      final questionPapers = response.map((data) {
        return QuestionPaperCloudModel.fromJson(data);
      }).toList();

      LoggingService.debug('Retrieved ${questionPapers.length} user question papers');
      return questionPapers;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException getting user question papers: ${e.message}');
      return [];
    } catch (e) {
      LoggingService.error('Error getting user question papers: $e');
      return [];
    }
  }

  // Update question paper status (for admin approval/rejection)
  Future<bool> updateQuestionPaperStatus({
    required String questionPaperId,
    required String newStatus,
    String? rejectionReason,
    String? reviewerId,
  }) async {
    try {
      LoggingService.debug('Updating question paper $questionPaperId status to: $newStatus');

      // Get reviewer ID from SharedPreferences if not provided
      String? finalReviewerId = reviewerId;
      if (finalReviewerId == null) {
        final userData = await _getCurrentUserData();
        finalReviewerId = userData['userId'];
      }

      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      // Add rejection reason if provided
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      // Add reviewer ID if available
      if (finalReviewerId != null) {
        updateData['reviewed_by'] = finalReviewerId;
      }

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', questionPaperId)
          .select()
          .single();

      LoggingService.debug('Question paper status updated successfully');
      return true;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException updating question paper status: ${e.message}');
      return false;
    } catch (e) {
      LoggingService.error('Error updating question paper status: $e');
      return false;
    }
  }

  // Get question paper by ID
  Future<QuestionPaperCloudModel?> getQuestionPaperById(String questionPaperId) async {
    try {
      LoggingService.debug('Fetching question paper by ID: $questionPaperId');

      final response = await _supabase
          .from(_tableName)
          .select('''
            *,
            created_by_name:profiles!question_papers_user_id_fkey(full_name),
            reviewed_by_name:profiles!question_papers_reviewed_by_fkey(full_name)
          ''')
          .eq('id', questionPaperId)
          .single();

      return QuestionPaperCloudModel.fromJson(response);
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException getting question paper by ID: ${e.message}');
      return null;
    } catch (e) {
      LoggingService.error('Error getting question paper by ID: $e');
      return null;
    }
  }

  // Search question papers
  Future<List<QuestionPaperCloudModel>> searchQuestionPapers({
    String? tenantId,
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  }) async {
    try {
      // Get tenant ID from SharedPreferences if not provided
      String? finalTenantId = tenantId;
      if (finalTenantId == null) {
        final userData = await _getCurrentUserData();
        finalTenantId = userData['tenantId'];

        if (finalTenantId == null) {
          LoggingService.error('Cannot search question papers: Missing tenant ID');
          return [];
        }
      }

      LoggingService.debug('Searching question papers with filters');

      var query = _supabase
          .from(_tableName)
          .select('''
            *,
            created_by_name:profiles!question_papers_user_id_fkey(full_name),
            reviewed_by_name:profiles!question_papers_reviewed_by_fkey(full_name)
          ''')
          .eq('tenant_id', finalTenantId);

      // Add filters
      if (status != null) {
        query = query.eq('status', status);
      }

      if (title != null && title.isNotEmpty) {
        query = query.ilike('title', '%$title%');
      }

      if (subject != null && subject.isNotEmpty) {
        query = query.ilike('subject', '%$subject%');
      }

      // Order by most recent first - call order() last and execute immediately
      final response = await query.order('submitted_at', ascending: false);

      var questionPapers = response.map((data) {
        return QuestionPaperCloudModel.fromJson(data);
      }).toList();

      // Additional filtering for created_by if needed
      if (createdBy != null && createdBy.isNotEmpty) {
        questionPapers = questionPapers.where((paper) {
          return paper.createdByName?.toLowerCase().contains(createdBy.toLowerCase()) ?? false;
        }).toList();
      }

      LoggingService.debug('Found ${questionPapers.length} question papers matching search criteria');
      return questionPapers;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException searching question papers: ${e.message}');
      return [];
    } catch (e) {
      LoggingService.error('Error searching question papers: $e');
      return [];
    }
  }

  // Delete question paper (hard delete)
  Future<bool> deleteQuestionPaper(String questionPaperId) async {
    try {
      LoggingService.debug('Deleting question paper: $questionPaperId');

      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', questionPaperId);

      LoggingService.debug('Question paper deleted successfully');
      return true;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException deleting question paper: ${e.message}');
      return false;
    } catch (e) {
      LoggingService.error('Error deleting question paper: $e');
      return false;
    }
  }

  // Get statistics for dashboard
  Future<Map<String, int>> getQuestionPaperStats([String? tenantId]) async {
    try {
      // Get tenant ID from SharedPreferences if not provided
      String? finalTenantId = tenantId;
      if (finalTenantId == null) {
        final userData = await _getCurrentUserData();
        finalTenantId = userData['tenantId'];

        if (finalTenantId == null) {
          LoggingService.error('Cannot get question paper stats: Missing tenant ID');
          return {'submitted': 0, 'approved': 0, 'rejected': 0};
        }
      }

      LoggingService.debug('Fetching question paper statistics for tenant: $finalTenantId');

      final response = await _supabase
          .from(_tableName)
          .select('status')
          .eq('tenant_id', finalTenantId);

      final stats = <String, int>{
        'submitted': 0,
        'approved': 0,
        'rejected': 0,
      };

      for (final row in response) {
        final status = row['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      LoggingService.debug('Question paper statistics: $stats');
      return stats;
    } on PostgrestException catch (e) {
      LoggingService.error('PostgrestException getting question paper stats: ${e.message}');
      return {'submitted': 0, 'approved': 0, 'rejected': 0};
    } catch (e) {
      LoggingService.error('Error getting question paper stats: $e');
      return {'submitted': 0, 'approved': 0, 'rejected': 0};
    }
  }

  // Convenience methods that automatically use SharedPreferences data
  Future<List<QuestionPaperCloudModel>> getMySubmittedQuestionPapers() async {
    return await getQuestionPapersByStatus(status: 'submitted');
  }

  Future<List<QuestionPaperCloudModel>> getMyApprovedQuestionPapers() async {
    return await getQuestionPapersByStatus(status: 'approved');
  }

  Future<List<QuestionPaperCloudModel>> getMyRejectedQuestionPapers() async {
    return await getQuestionPapersByStatus(status: 'rejected');
  }

  Future<List<QuestionPaperCloudModel>> getMyQuestionPapers() async {
    return await getUserQuestionPapers();
  }
}

// Cloud model for question papers stored in Supabase
class QuestionPaperCloudModel {
  final String id;
  final String tenantId;
  final String userId;
  final String title;
  final String subject;
  final String examType;
  final Map<String, List<Question>> questions;
  final String status;
  final DateTime createdAt;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;
  final String? createdByName;
  final String? reviewedByName;

  QuestionPaperCloudModel({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.title,
    required this.subject,
    required this.examType,
    required this.questions,
    required this.status,
    required this.createdAt,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.metadata,
    this.createdByName,
    this.reviewedByName,
  });

  factory QuestionPaperCloudModel.fromJson(Map<String, dynamic> json) {
    // Parse questions from JSONB
    final questionsJson = json['questions'] as Map<String, dynamic>;
    final questions = <String, List<Question>>{};

    questionsJson.forEach((key, value) {
      final questionList = (value as List).map((q) => Question.fromJson(q)).toList();
      questions[key] = questionList;
    });

    return QuestionPaperCloudModel(
      id: json['id'],
      tenantId: json['tenant_id'],
      userId: json['user_id'],
      title: json['title'],
      subject: json['subject'],
      examType: json['exam_type'],
      questions: questions,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      submittedAt: DateTime.parse(json['submitted_at']),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      reviewedBy: json['reviewed_by'],
      rejectionReason: json['rejection_reason'],
      metadata: json['metadata'],
      createdByName: json['created_by_name']?['full_name'],
      reviewedByName: json['reviewed_by_name']?['full_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'title': title,
      'subject': subject,
      'exam_type': examType,
      'questions': questions.map((key, value) =>
          MapEntry(key, value.map((q) => q.toJson()).toList())),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
      'metadata': metadata,
      'created_by_name': createdByName,
      'reviewed_by_name': reviewedByName,
    };
  }

  // Convert to local QuestionPaperModel for editing
  QuestionPaperModel toLocalModel() {
    return QuestionPaperModel(
      id: id,
      title: title,
      subject: subject,
      examType: examType,
      createdBy: createdByName ?? 'Unknown',
      createdAt: createdAt,
      modifiedAt: reviewedAt ?? submittedAt,
      status: status == 'approved' ? 'approved' : 'draft', // Convert to local status
      examTypeEntity: metadata?['exam_type_entity'] != null
          ? ExamTypeEntity.fromJson(metadata!['exam_type_entity'])
          : ExamTypeEntity(id: '', tenantId: '', name: ''), // Fixed syntax error
      questions: questions,
      selectedSubjects: metadata?['selected_subjects'] != null
          ? (metadata!['selected_subjects'] as List)
          .map((s) => SubjectEntity.fromJson(s))
          .toList()
          : [],
      rejectionReason: rejectionReason,
      approvedBy: reviewedByName,
      approvedAt: reviewedAt,
    );
  }
}