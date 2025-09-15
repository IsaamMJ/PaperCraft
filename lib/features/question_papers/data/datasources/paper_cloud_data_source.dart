// features/question_papers/data/datasources/paper_cloud_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question_paper_model.dart';

abstract class PaperCloudDataSource {
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper);
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId);
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId);
  Future<QuestionPaperModel> updatePaperStatus(String id, String status, {String? reason, String? reviewerId});
  Future<QuestionPaperModel?> getPaperById(String id);
  Future<void> deletePaper(String id);
  Future<List<QuestionPaperModel>> searchPapers(String tenantId, {
    String? title,
    String? subject,
    String? status,
    String? userId,
  });
}

class PaperCloudDataSourceImpl implements PaperCloudDataSource {
  final SupabaseClient _supabase;
  static const String _tableName = 'question_papers';

  PaperCloudDataSourceImpl(this._supabase);

  @override
  Future<QuestionPaperModel> submitPaper(QuestionPaperModel paper) async {
    try {
      final data = paper.toSupabaseMap();

      final response = await _supabase
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      return QuestionPaperModel.fromSupabase(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit paper: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error submitting paper: $e');
    }
  }

  @override
  Future<List<QuestionPaperModel>> getUserSubmissions(String tenantId, String userId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .order('submitted_at', ascending: false);

      return response.map<QuestionPaperModel>((json) =>
          QuestionPaperModel.fromSupabase(json)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to get user submissions: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting submissions: $e');
    }
  }

  @override
  Future<List<QuestionPaperModel>> getPapersForReview(String tenantId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('tenant_id', tenantId)
          .eq('status', 'submitted')
          .order('submitted_at', ascending: false);

      return response.map<QuestionPaperModel>((json) =>
          QuestionPaperModel.fromSupabase(json)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to get papers for review: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting papers for review: $e');
    }
  }

  @override
  Future<QuestionPaperModel> updatePaperStatus(String id, String status, {String? reason, String? reviewerId}) async {
    try {
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

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return QuestionPaperModel.fromSupabase(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update paper status: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating paper status: $e');
    }
  }

  @override
  Future<QuestionPaperModel?> getPaperById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? QuestionPaperModel.fromSupabase(response) : null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to get paper by ID: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error getting paper: $e');
    }
  }

  @override
  Future<void> deletePaper(String id) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete paper: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting paper: $e');
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
      var query = _supabase
          .from(_tableName)
          .select()
          .eq('tenant_id', tenantId);

      if (status != null) query = query.eq('status', status);
      if (userId != null) query = query.eq('user_id', userId);
      if (title != null) query = query.ilike('title', '%$title%');
      if (subject != null) query = query.ilike('subject', '%$subject%');

      final response = await query.order('submitted_at', ascending: false);

      return response.map<QuestionPaperModel>((json) =>
          QuestionPaperModel.fromSupabase(json)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to search papers: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error searching papers: $e');
    }
  }
}