// features/question_papers/data/datasources/exam_type_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/exam_type_model.dart';

abstract class ExamTypeDataSource {
  Future<List<ExamTypeModel>> getExamTypes(String tenantId);
  Future<List<ExamTypeModel>> getExamTypesBySubject(String tenantId, String subjectId);  // ADDED
  Future<ExamTypeModel?> getExamTypeById(String id);
}

class ExamTypeSupabaseDataSource implements ExamTypeDataSource {
  final SupabaseClient _supabaseClient;
  final ILogger _logger;

  ExamTypeSupabaseDataSource(this._supabaseClient, this._logger);

  @override
  Future<List<ExamTypeModel>> getExamTypes(String tenantId) async {
    try {
      final response = await _supabaseClient
          .from('exam_types')
          .select('*')
          .eq('tenant_id', tenantId)
          .eq('is_active', true)  // ADDED
          .order('name');

      return response.map((json) => ExamTypeModel.fromJson(json)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam types',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      throw Exception('Failed to fetch exam types: ${e.toString()}');
    }
  }

  @override
  Future<List<ExamTypeModel>> getExamTypesBySubject(
      String tenantId,
      String subjectId,
      ) async {
    try {
      _logger.debug('Fetching exam types by subject', category: LogCategory.examtype, context: {
        'tenantId': tenantId,
        'subjectId': subjectId,
      });

      final response = await _supabaseClient
          .from('exam_types')
          .select('*')
          .eq('tenant_id', tenantId)
          .eq('subject_id', subjectId)
          .eq('is_active', true)
          .order('name');

      return response.map((json) => ExamTypeModel.fromJson(json)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam types by subject',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      throw Exception('Failed to fetch exam types: ${e.toString()}');
    }
  }

  @override
  Future<ExamTypeModel?> getExamTypeById(String id) async {
    try {
      final response = await _supabaseClient
          .from('exam_types')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam type by ID',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      throw Exception('Failed to fetch exam type: ${e.toString()}');
    }
  }
}