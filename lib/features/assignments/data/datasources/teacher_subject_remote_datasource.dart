import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/teacher_subject.dart';

/// Abstract interface for teacher subject remote data operations
abstract class TeacherSubjectRemoteDataSource {
  /// Get all subjects assigned to a teacher for a given academic year
  Future<List<TeacherSubject>> getTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    bool activeOnly = true,
  });

  /// Get all teachers assigned to a specific (grade, subject, section)
  /// Used when publishing timetable to find which teachers need papers
  ///
  /// Now includes teacher names via join with profiles table
  Future<List<TeacherSubject>> getTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
    bool activeOnly = true,
  });

  /// Save all assignments for a teacher (replace operation)
  /// Deletes existing assignments for this teacher+year, then inserts new ones
  Future<void> saveTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  });

  /// Soft delete a single assignment
  Future<void> deactivateTeacherSubject(String id);

  /// Get single assignment by ID
  Future<TeacherSubject?> getTeacherSubjectById(String id);

  /// Count total teachers assigned to (grade, subject, section)
  Future<int> countTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
  });
}

/// Implementation using Supabase
class TeacherSubjectRemoteDataSourceImpl implements TeacherSubjectRemoteDataSource {
  final SupabaseClient supabaseClient;

  TeacherSubjectRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<TeacherSubject>> getTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('teacher_subjects')
          .select()
          .eq('tenant_id', tenantId)
          .eq('teacher_id', teacherId)
          .eq('academic_year', academicYear);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query;

      return List<TeacherSubject>.from(
        response.map((json) => TeacherSubject.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TeacherSubject>> getTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
    bool activeOnly = true,
  }) async {
    try {
      // FIXED: Add join to profiles table to get teacher names
      var query = supabaseClient
          .from('teacher_subjects')
          .select('''
            id,
            tenant_id,
            teacher_id,
            grade_id,
            subject_id,
            section,
            academic_year,
            is_active,
            created_at,
            updated_at,
            profiles(full_name)
          ''')
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('subject_id', subjectId)
          .eq('section', section)
          .eq('academic_year', academicYear);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query;

      return List<TeacherSubject>.from(
        response.map((json) => _mapJsonToTeacherSubject(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  }) async {
    try {
      // Step 1: Delete existing assignments for this teacher+year
      await supabaseClient
          .from('teacher_subjects')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('teacher_id', teacherId)
          .eq('academic_year', academicYear);

      // Step 2: Insert new assignments
      if (assignments.isNotEmpty) {
        final data = assignments.map((a) => a.toJson()).toList();
        await supabaseClient
            .from('teacher_subjects')
            .insert(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deactivateTeacherSubject(String id) async {
    try {
      await supabaseClient
          .from('teacher_subjects')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TeacherSubject?> getTeacherSubjectById(String id) async {
    try {
      final response = await supabaseClient
          .from('teacher_subjects')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return TeacherSubject.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> countTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
  }) async {
    try {
      final response = await supabaseClient
          .from('teacher_subjects')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('subject_id', subjectId)
          .eq('section', section)
          .eq('academic_year', academicYear)
          .eq('is_active', true);

      return response.length;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper to map JSON response (with teacher name from join) to TeacherSubject
  TeacherSubject _mapJsonToTeacherSubject(Map<String, dynamic> json) {
    // Extract teacher name from joined profiles table
    final profile = json['profiles'] as Map<String, dynamic>?;
    final teacherName = profile?['full_name'] as String?;

    // Create TeacherSubject with teacher name
    final teacherSubject = TeacherSubject.fromJson(json);

    // Return with teacher name set
    return teacherSubject.copyWith(
      teacherName: teacherName,
    );
  }
}