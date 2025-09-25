// features/question_papers/data/datasources/exam_type_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/exam_type_model.dart';

abstract class ExamTypeDataSource {
  Future<List<ExamTypeModel>> getExamTypes(String tenantId);
  Future<ExamTypeModel?> getExamTypeById(String id);
  Future<ExamTypeModel> createExamType(ExamTypeModel examType);
  Future<ExamTypeModel> updateExamType(ExamTypeModel examType);
  Future<void> deleteExamType(String id);
}

class ExamTypeSupabaseDataSource implements ExamTypeDataSource {
  final SupabaseClient _supabaseClient;
  final ILogger _logger;

  ExamTypeSupabaseDataSource(this._supabaseClient, this._logger);

  @override
  Future<List<ExamTypeModel>> getExamTypes(String tenantId) async {
    try {
      _logger.debug('Fetching exam types for tenant', category: LogCategory.examtype, context: {
        'tenantId': tenantId,
        'operation': 'get_exam_types',
      });

      // ADD DEBUG LOGGING
      print('=== DEBUG: Exam Types Query ===');
      print('Tenant ID: $tenantId');
      print('Query: SELECT * FROM exam_types WHERE tenant_id = $tenantId');
      print('===============================');

      final response = await _supabaseClient
          .from('exam_types')
          .select('*')
          .eq('tenant_id', tenantId)
          .order('name');

      // ADD MORE DEBUG
      print('=== DEBUG: Query Response ===');
      print('Response length: ${response.length}');
      print('Response data: $response');
      print('=============================');

      _logger.info('Exam types fetched successfully', category: LogCategory.examtype, context: {
        'tenantId': tenantId,
        'count': response.length,
        'operation': 'get_exam_types',
      });

      return response.map((json) => ExamTypeModel.fromJson(json)).toList();
    } catch (e, stackTrace) {

      // ADD ERROR DEBUG
      print('=== DEBUG: Query Error ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==========================');

      _logger.error('Failed to fetch exam types',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'tenantId': tenantId,
            'operation': 'get_exam_types',
          }
      );
      throw Exception('Failed to fetch exam types: ${e.toString()}');
    }
  }

  @override
  Future<ExamTypeModel?> getExamTypeById(String id) async {
    try {
      _logger.debug('Fetching exam type by ID', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'get_exam_type_by_id',
      });

      final response = await _supabaseClient
          .from('exam_types')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        _logger.debug('Exam type not found', category: LogCategory.examtype, context: {
          'examTypeId': id,
          'operation': 'get_exam_type_by_id',
        });
        return null;
      }

      _logger.debug('Exam type found', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'examTypeName': response['name'],
        'operation': 'get_exam_type_by_id',
      });

      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch exam type by ID',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': id,
            'operation': 'get_exam_type_by_id',
          }
      );
      throw Exception('Failed to fetch exam type: ${e.toString()}');
    }
  }

  @override
  Future<ExamTypeModel> createExamType(ExamTypeModel examType) async {
    try {
      _logger.info('Creating new exam type', category: LogCategory.examtype, context: {
        'examTypeName': examType.name,
        'tenantId': examType.tenantId,
        'operation': 'create_exam_type',
      });

      final response = await _supabaseClient
          .from('exam_types')
          .insert(examType.toJson())
          .select()
          .single();

      _logger.info('Exam type created successfully', category: LogCategory.examtype, context: {
        'examTypeId': response['id'],
        'examTypeName': examType.name,
        'tenantId': examType.tenantId,
        'operation': 'create_exam_type',
      });

      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to create exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeName': examType.name,
            'tenantId': examType.tenantId,
            'operation': 'create_exam_type',
          }
      );
      throw Exception('Failed to create exam type: ${e.toString()}');
    }
  }

  @override
  Future<ExamTypeModel> updateExamType(ExamTypeModel examType) async {
    try {
      _logger.info('Updating exam type', category: LogCategory.examtype, context: {
        'examTypeId': examType.id,
        'examTypeName': examType.name,
        'operation': 'update_exam_type',
      });

      final response = await _supabaseClient
          .from('exam_types')
          .update(examType.toJson())
          .eq('id', examType.id)
          .select()
          .single();

      _logger.info('Exam type updated successfully', category: LogCategory.examtype, context: {
        'examTypeId': examType.id,
        'examTypeName': examType.name,
        'operation': 'update_exam_type',
      });

      return ExamTypeModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to update exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': examType.id,
            'operation': 'update_exam_type',
          }
      );
      throw Exception('Failed to update exam type: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteExamType(String id) async {
    try {
      _logger.info('Deleting exam type', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'delete_exam_type',
      });

      await _supabaseClient
          .from('exam_types')
          .delete()
          .eq('id', id);

      _logger.info('Exam type deleted successfully', category: LogCategory.examtype, context: {
        'examTypeId': id,
        'operation': 'delete_exam_type',
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to delete exam type',
          category: LogCategory.examtype,
          error: e,
          stackTrace: stackTrace,
          context: {
            'examTypeId': id,
            'operation': 'delete_exam_type',
          }
      );
      throw Exception('Failed to delete exam type: ${e.toString()}');
    }
  }
}