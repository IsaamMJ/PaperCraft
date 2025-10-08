// features/question_papers/data/datasources/exam_type_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/exam_type_model.dart';

abstract class ExamTypeDataSource {
  Future<List<ExamTypeModel>> getExamTypes(String tenantId);
  Future<List<ExamTypeModel>> getExamTypesBySubject(String tenantId, String subjectId);
  Future<ExamTypeModel?> getExamTypeById(String id);

  // CRUD operations
  Future<ExamTypeModel> createExamType(ExamTypeModel examType);
  Future<ExamTypeModel> updateExamType(ExamTypeModel examType);
  Future<void> deleteExamType(String id);
}

class ExamTypeSupabaseDataSource implements ExamTypeDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  ExamTypeSupabaseDataSource(this._supabase, this._logger);

  @override
  Future<List<ExamTypeModel>> getExamTypes(String tenantId) async {
    try {
      final response = await _supabase
          .from('exam_types')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => ExamTypeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam types',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<ExamTypeModel>> getExamTypesBySubject(
      String tenantId,
      String subjectId,
      ) async {
    try {
      _logger.debug('Fetching exam types by subject',
          category: LogCategory.examtype,
          context: {
            'tenantId': tenantId,
            'subjectId': subjectId,
          });

      final response = await _supabase
          .from('exam_types')
          .select()
          .eq('tenant_id', tenantId)
          .eq('subject_id', subjectId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((json) => ExamTypeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam types by subject',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ExamTypeModel?> getExamTypeById(String id) async {
    try {
      final response = await _supabase
          .from('exam_types')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam type by ID',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ExamTypeModel> createExamType(ExamTypeModel examType) async {
    try {
      _logger.info('Creating exam type',
          category: LogCategory.examtype,
          context: {
            'name': examType.name,
            'tenantId': examType.tenantId,
            'subjectId': examType.subjectId,
          });

      final data = examType.toJson();
      // Remove ID for INSERT - let database generate it
      data.remove('id');
      data.remove('created_at'); // Let DB set timestamp

      final response = await _supabase
          .from('exam_types')
          .insert(data)
          .select()
          .single();

      _logger.info('Exam type created successfully',
          category: LogCategory.examtype,
          context: {
            'id': response['id'],
            'name': response['name'],
          });

      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to create exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<ExamTypeModel> updateExamType(ExamTypeModel examType) async {
    try {
      _logger.info('Updating exam type',
          category: LogCategory.examtype,
          context: {
            'id': examType.id,
            'name': examType.name,
          });

      final data = examType.toJson();
      // Don't update these fields
      data.remove('id');
      data.remove('tenant_id');
      data.remove('created_at');

      final response = await _supabase
          .from('exam_types')
          .update(data)
          .eq('id', examType.id)
          .select()
          .single();

      _logger.info('Exam type updated successfully',
          category: LogCategory.examtype,
          context: {
            'id': examType.id,
            'name': examType.name,
          });

      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to update exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteExamType(String id) async {
    try {
      _logger.info('Deleting exam type',
          category: LogCategory.examtype,
          context: {'id': id});

      // Soft delete by setting is_active = false
      await _supabase
          .from('exam_types')
          .update({'is_active': false})
          .eq('id', id);

      _logger.info('Exam type deleted successfully',
          category: LogCategory.examtype,
          context: {'id': id});
    } catch (e, stackTrace) {
      _logger.error('Failed to delete exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
}