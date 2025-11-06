import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';

/// Datasource for teacher assignment operations (settings/management screen)
///
/// Handles Supabase queries with joins to fetch complete assignment data
/// including display fields (teacher names, grades, sections, subjects)
abstract class TeacherAssignmentDataSource {
  /// Get all teacher assignments with all display fields populated
  ///
  /// Joins:
  /// - teacher_subjects: base table
  /// - profiles: teacher name and email
  /// - grades: grade number
  /// - subjects: subject name
  /// - grade_sections: section name
  ///
  /// Returns entities ready for UI display
  Future<List<TeacherSubjectAssignmentEntity>> getTeacherAssignments({
    required String tenantId,
    String? teacherId,
    String academicYear = '2025-2026',
    bool activeOnly = true,
  });

  /// Get assignment count by grade+section
  ///
  /// Returns map like {"2:A": 3, "2:B": 2, "5:A": 4}
  Future<Map<String, int>> getAssignmentStats({
    required String tenantId,
    String academicYear = '2025-2026',
  });

  /// Save or update a single assignment (UPSERT)
  ///
  /// Uses Supabase upsert to ensure idempotency
  Future<void> saveAssignment(TeacherSubjectAssignmentEntity assignment);

  /// Soft delete by setting is_active = false
  Future<void> deleteAssignment(String assignmentId);

  /// Get single assignment by ID
  Future<TeacherSubjectAssignmentEntity?> getAssignmentById(String id);

  /// Get assignments for a specific teacher
  Future<List<TeacherSubjectAssignmentEntity>> getAssignmentsForTeacher({
    required String tenantId,
    required String teacherId,
    String academicYear = '2025-2026',
  });
}

/// Implementation using Supabase
class TeacherAssignmentDataSourceImpl implements TeacherAssignmentDataSource {
  final SupabaseClient supabaseClient;

  TeacherAssignmentDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<TeacherSubjectAssignmentEntity>> getTeacherAssignments({
    required String tenantId,
    String? teacherId,
    String academicYear = '2025-2026',
    bool activeOnly = true,
  }) async {
    try {
      // Build query with joins to get all display fields
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
            start_date,
            end_date,
            is_active,
            created_at,
            updated_at,
            profiles(full_name, email),
            grades(grade_number),
            subjects(subject_catalog(subject_name))
          ''')
          .eq('tenant_id', tenantId)
          .eq('academic_year', academicYear);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (teacherId != null) {
        query = query.eq('teacher_id', teacherId);
      }

      final response = await query;

      return (response as List)
          .map((json) => _mapJsonToEntity(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, int>> getAssignmentStats({
    required String tenantId,
    String academicYear = '2025-2026',
  }) async {
    try {
      // Get all active assignments grouped by grade+section
      final response = await supabaseClient
          .from('teacher_subjects')
          .select('grade_id, section, grades(grade_number)')
          .eq('tenant_id', tenantId)
          .eq('academic_year', academicYear)
          .eq('is_active', true);

      final stats = <String, int>{};

      for (final record in response as List) {
        final gradeData = record['grades'] as Map<String, dynamic>?;
        final gradeNumber = gradeData?['grade_number'] as int?;
        final section = record['section'] as String?;

        if (gradeNumber != null && section != null) {
          final key = '$gradeNumber:$section';
          stats[key] = (stats[key] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveAssignment(TeacherSubjectAssignmentEntity assignment) async {
    try {
      final data = {
        'id': assignment.id,
        'tenant_id': assignment.tenantId,
        'teacher_id': assignment.teacherId,
        'grade_id': assignment.gradeId,
        'subject_id': assignment.subjectId,
        'section': assignment.section,
        'academic_year': assignment.academicYear,
        'start_date': assignment.startDate != null
            ? assignment.startDate!.toIso8601String().split('T')[0]
            : null,
        'end_date': assignment.endDate != null
            ? assignment.endDate!.toIso8601String().split('T')[0]
            : null,
        'is_active': assignment.isActive,
        'created_at': assignment.createdAt.toIso8601String(),
        'updated_at': assignment.updatedAt?.toIso8601String(),
      };

      // UPSERT: insert if not exists, update if exists
      await supabaseClient.from('teacher_subjects').upsert(
        data,
        onConflict: 'id',
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await supabaseClient
          .from('teacher_subjects')
          .update({'is_active': false})
          .eq('id', assignmentId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TeacherSubjectAssignmentEntity?> getAssignmentById(String id) async {
    try {
      final response = await supabaseClient
          .from('teacher_subjects')
          .select('''
            id,
            tenant_id,
            teacher_id,
            grade_id,
            subject_id,
            section,
            academic_year,
            start_date,
            end_date,
            is_active,
            created_at,
            updated_at,
            profiles(full_name, email),
            grades(grade_number),
            subjects(subject_catalog(subject_name))
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return _mapJsonToEntity(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TeacherSubjectAssignmentEntity>> getAssignmentsForTeacher({
    required String tenantId,
    required String teacherId,
    String academicYear = '2025-2026',
  }) async {
    try {
      final response = await supabaseClient
          .from('teacher_subjects')
          .select('''
            id,
            tenant_id,
            teacher_id,
            grade_id,
            subject_id,
            section,
            academic_year,
            start_date,
            end_date,
            is_active,
            created_at,
            updated_at,
            profiles(full_name, email),
            grades(grade_number),
            subjects(subject_catalog(subject_name))
          ''')
          .eq('tenant_id', tenantId)
          .eq('teacher_id', teacherId)
          .eq('academic_year', academicYear)
          .eq('is_active', true);

      return (response as List)
          .map((json) => _mapJsonToEntity(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Helper to map Supabase JSON response (with joins) to entity
  ///
  /// Handles nested objects from joined tables:
  /// - profiles: {full_name, email}
  /// - grades: {grade_number}
  /// - subjects: {subject_catalog: {subject_name}} (nested join through subject_catalog)
  /// Extracts section directly from teacher_subjects table
  TeacherSubjectAssignmentEntity _mapJsonToEntity(Map<String, dynamic> json) {
    // Extract profile data (joined from profiles table)
    final profile = json['profiles'] as Map<String, dynamic>?;
    final teacherName = profile?['full_name'] as String?;
    final teacherEmail = profile?['email'] as String?;

    // Extract grade data (joined from grades table)
    final gradeData = json['grades'] as Map<String, dynamic>?;
    final gradeNumber = gradeData?['grade_number'] as int?;

    // Extract subject data (nested join: subjects -> subject_catalog)
    final subjectData = json['subjects'] as Map<String, dynamic>?;
    final subjectCatalog = subjectData?['subject_catalog'] as Map<String, dynamic>?;
    final subjectName = subjectCatalog?['subject_name'] as String?;

    // Extract section directly from teacher_subjects table
    final section = json['section'] as String?;

    // Parse date fields
    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;
    final startDateStr = json['start_date'] as String?;
    final endDateStr = json['end_date'] as String?;

    final createdAt =
        createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
    final updatedAt = updatedAtStr != null ? DateTime.parse(updatedAtStr) : null;
    final startDate = startDateStr != null ? DateTime.parse(startDateStr) : DateTime.now();
    final endDate = endDateStr != null ? DateTime.parse(endDateStr) : null;

    return TeacherSubjectAssignmentEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      teacherId: json['teacher_id'] as String,
      gradeId: json['grade_id'] as String,
      subjectId: json['subject_id'] as String,
      teacherName: teacherName,
      teacherEmail: teacherEmail,
      gradeNumber: gradeNumber,
      section: section,
      subjectName: subjectName,
      academicYear: json['academic_year'] as String? ?? '2025-2026',
      startDate: startDate,
      endDate: endDate,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
