// features/catalog/data/datasources/grade_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/grade_model.dart';

abstract class GradeDataSource {
  Future<List<GradeModel>> getGrades(String tenantId);
  Future<GradeModel?> getGradeById(String id);
  Future<GradeModel> createGrade(GradeModel grade);
  Future<GradeModel> updateGrade(GradeModel grade);
  Future<void> deleteGrade(String id);
  Future<List<GradeModel>> getAssignedGrades(
      String tenantId,
      String teacherId,
      String academicYear,
      );
}

class GradeDataSourceImpl implements GradeDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  GradeDataSourceImpl(this._supabase, this._logger);

  @override
  Future<List<GradeModel>> getAssignedGrades(
      String tenantId,
      String teacherId,
      String academicYear,
      ) async {
    try {
      _logger.debug('Fetching assigned grades for teacher',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'academicYear': academicYear,
          });

      final response = await _supabase
          .from('grades')
          .select('''
          *,
          teacher_grade_assignments!inner(
            teacher_id,
            academic_year,
            is_active
          )
        ''')
          .eq('tenant_id', tenantId)
          .eq('teacher_grade_assignments.teacher_id', teacherId)
          .eq('teacher_grade_assignments.academic_year', academicYear)
          .eq('teacher_grade_assignments.is_active', true)
          .eq('is_active', true)
          .order('grade_number');

      _logger.info('Assigned grades fetched',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'count': (response as List).length,
          });

      return (response as List)
          .map((json) => GradeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch assigned grades',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }



  @override
  Future<List<GradeModel>> getGrades(String tenantId) async {
    try {
      _logger.debug('Fetching grades',
          category: LogCategory.storage,
          context: {'tenantId': tenantId});

      final response = await _supabase
          .from('grades')
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .order('grade_number');

      _logger.info('Grades fetched',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'count': (response as List).length,
          });

      return (response as List)
          .map((json) => GradeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<GradeModel?> getGradeById(String id) async {
    try {
      final response = await _supabase
          .from('grades')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return GradeModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grade by ID',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<GradeModel> createGrade(GradeModel grade) async {
    try {
      _logger.info('Creating grade',
          category: LogCategory.storage,
          context: {
            'gradeNumber': grade.gradeNumber,
            'tenantId': grade.tenantId,
          });

      final data = {
        'tenant_id': grade.tenantId,
        'grade_number': grade.gradeNumber,
        'is_active': true,
      };

      final response = await _supabase
          .from('grades')
          .insert(data)
          .select()
          .single();

      _logger.info('Grade created successfully',
          category: LogCategory.storage,
          context: {
            'id': response['id'],
            'gradeNumber': response['grade_number'],
          });

      return GradeModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Failed to create grade',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<GradeModel> updateGrade(GradeModel grade) async {
    try {
      _logger.info('Updating grade',
          category: LogCategory.storage,
          context: {
            'id': grade.id,
            'gradeNumber': grade.gradeNumber,
          });

      final data = {
        'grade_number': grade.gradeNumber,
        'is_active': grade.isActive,
      };

      final response = await _supabase
          .from('grades')
          .update(data)
          .eq('id', grade.id)
          .select()
          .single();

      _logger.info('Grade updated successfully',
          category: LogCategory.storage,
          context: {
            'id': grade.id,
            'gradeNumber': grade.gradeNumber,
          });

      return GradeModel.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      _logger.error('Failed to update grade',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteGrade(String id) async {
    try {
      _logger.info('Deleting grade',
          category: LogCategory.storage,
          context: {'id': id});

      await _supabase
          .from('grades')
          .update({'is_active': false})
          .eq('id', id);

      _logger.info('Grade deleted successfully',
          category: LogCategory.storage,
          context: {'id': id});
    } catch (e, stackTrace) {
      _logger.error('Failed to delete grade',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
}