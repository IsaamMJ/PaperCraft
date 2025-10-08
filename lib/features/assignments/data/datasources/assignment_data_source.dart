// features/assignments/data/datasources/assignment_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/teacher_grade_assignment_model.dart';
import '../models/teacher_subject_assignment_model.dart';

abstract class AssignmentDataSource {
  // Grade Assignments
  Future<List<TeacherGradeAssignmentModel>> getTeacherGradeAssignments(
      String teacherId,
      String academicYear,
      );
  Future<TeacherGradeAssignmentModel> assignGradeToTeacher({
    required String tenantId,
    required String teacherId,
    required String gradeId,
    required String academicYear,
  });
  Future<void> removeGradeAssignment(String assignmentId);

  // Subject Assignments
  Future<List<TeacherSubjectAssignmentModel>> getTeacherSubjectAssignments(
      String teacherId,
      String academicYear,
      );
  Future<TeacherSubjectAssignmentModel> assignSubjectToTeacher({
    required String tenantId,
    required String teacherId,
    required String subjectId,
    required String academicYear,
  });
  Future<void> removeSubjectAssignment(String assignmentId);
}

class AssignmentDataSourceImpl implements AssignmentDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  AssignmentDataSourceImpl(this._supabase, this._logger);

  // ========== GRADE ASSIGNMENTS ==========

  @override
  Future<List<TeacherGradeAssignmentModel>> getTeacherGradeAssignments(
      String teacherId,
      String academicYear,
      ) async {
    try {
      _logger.debug('Fetching teacher grade assignments',
          category: LogCategory.storage,
          context: {
            'teacherId': teacherId,
            'academicYear': academicYear,
          });

      final response = await _supabase
          .from('teacher_grade_assignments')
          .select()
          .eq('teacher_id', teacherId)
          .eq('academic_year', academicYear)
          .eq('is_active', true);

      _logger.info('Teacher grade assignments fetched',
          category: LogCategory.storage,
          context: {
            'teacherId': teacherId,
            'count': (response as List).length,
          });

      return (response as List)
          .map((json) => TeacherGradeAssignmentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch teacher grade assignments',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<TeacherGradeAssignmentModel> assignGradeToTeacher({
    required String tenantId,
    required String teacherId,
    required String gradeId,
    required String academicYear,
  }) async {
    try {
      _logger.info('Assigning grade to teacher',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'gradeId': gradeId,
            'academicYear': academicYear,
          });

      final data = {
        'tenant_id': tenantId,
        'teacher_id': teacherId,
        'grade_id': gradeId,
        'academic_year': academicYear,
        'is_active': true,
      };

      final response = await _supabase
          .from('teacher_grade_assignments')
          .insert(data)
          .select()
          .single();

      _logger.info('Grade assigned successfully',
          category: LogCategory.storage,
          context: {
            'assignmentId': response['id'],
          });

      return TeacherGradeAssignmentModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to assign grade to teacher',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeGradeAssignment(String assignmentId) async {
    try {
      _logger.info('Removing grade assignment',
          category: LogCategory.storage,
          context: {'assignmentId': assignmentId});

      await _supabase
          .from('teacher_grade_assignments')
          .delete()
          .eq('id', assignmentId);

      _logger.info('Grade assignment removed successfully',
          category: LogCategory.storage);
    } catch (e, stackTrace) {
      _logger.error('Failed to remove grade assignment',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  // ========== SUBJECT ASSIGNMENTS ==========

  @override
  Future<List<TeacherSubjectAssignmentModel>> getTeacherSubjectAssignments(
      String teacherId,
      String academicYear,
      ) async {
    try {
      _logger.debug('Fetching teacher subject assignments',
          category: LogCategory.storage,
          context: {
            'teacherId': teacherId,
            'academicYear': academicYear,
          });

      final response = await _supabase
          .from('teacher_subject_assignments')
          .select()
          .eq('teacher_id', teacherId)
          .eq('academic_year', academicYear)
          .eq('is_active', true);

      _logger.info('Teacher subject assignments fetched',
          category: LogCategory.storage,
          context: {
            'teacherId': teacherId,
            'count': (response as List).length,
          });

      return (response as List)
          .map((json) => TeacherSubjectAssignmentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch teacher subject assignments',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<TeacherSubjectAssignmentModel> assignSubjectToTeacher({
    required String tenantId,
    required String teacherId,
    required String subjectId,
    required String academicYear,
  }) async {
    try {
      _logger.info('Assigning subject to teacher',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'subjectId': subjectId,
            'academicYear': academicYear,
          });

      final data = {
        'tenant_id': tenantId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'academic_year': academicYear,
        'is_active': true,
      };

      final response = await _supabase
          .from('teacher_subject_assignments')
          .insert(data)
          .select()
          .single();

      _logger.info('Subject assigned successfully',
          category: LogCategory.storage,
          context: {
            'assignmentId': response['id'],
          });

      return TeacherSubjectAssignmentModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to assign subject to teacher',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> removeSubjectAssignment(String assignmentId) async {
    try {
      _logger.info('Removing subject assignment',
          category: LogCategory.storage,
          context: {'assignmentId': assignmentId});

      await _supabase
          .from('teacher_subject_assignments')
          .delete()
          .eq('id', assignmentId);

      _logger.info('Subject assignment removed successfully',
          category: LogCategory.storage);
    } catch (e, stackTrace) {
      _logger.error('Failed to remove subject assignment',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }
}