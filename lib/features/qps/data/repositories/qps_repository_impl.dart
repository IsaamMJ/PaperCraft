// data/repositories/qps_repository_impl.dart - FIXED VERSION
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/user_permissions_entity.dart';
import '../../domain/repositories/qps_repository.dart';

class QpsRepositoryImpl implements QpsRepository {
  final SupabaseClient supabase;
  final String? tenantId; // Optional: for testing/mocking

  QpsRepositoryImpl({
    required this.supabase,
    this.tenantId,
  });

  /// Retrieves tenantId from constructor or SharedPreferences
  Future<String> _getTenantId() async {
    if (tenantId != null && tenantId!.isNotEmpty) return tenantId!;
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('tenant_id'); // ✅ Correct key
    if (savedId == null || savedId.isEmpty) {
      throw Exception('Tenant ID not found in SharedPreferences');
    }
    return savedId;
  }

  /// Retrieves current user ID from SharedPreferences
  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id'); // ✅ Correct key
    if (userId == null || userId.isEmpty) {
      throw Exception('User ID not found in SharedPreferences');
    }
    return userId;
  }

  /// Get current user role from SharedPreferences - FIXED!
  Future<String> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 FIX: Use the correct key that matches LocalStorageDataSource
    final role = prefs.getString('user_role'); // Changed from 'role' to 'user_role'

    if (role == null || role.isEmpty) {
      // Additional debugging
      print('DEBUG: Available SharedPreferences keys: ${prefs.getKeys()}');
      print('DEBUG: All stored values:');
      for (String key in prefs.getKeys()) {
        print('  $key: ${prefs.get(key)}');
      }
      throw Exception('User role not found in SharedPreferences');
    }
    return role;
  }

  @override
  Future<List<ExamTypeEntity>> getExamTypes() async {
    final id = await _getTenantId();
    final data = await supabase
        .from('exam_types')
        .select('id, name, sections')
        .eq('tenant_id', id) as List<dynamic>;

    return data
        .map((e) => ExamTypeEntity(
      id: e['id'] as String,
      tenantId: id,
      name: e['name'] as String,
      sections: _parseSections(e['sections']),
    ))
        .toList();
  }

  /// Parse sections JSON to List<ExamSectionEntity>
  List<ExamSectionEntity> _parseSections(dynamic sectionsJson) {
    if (sectionsJson == null) return [];

    try {
      final List<dynamic> sectionsList = sectionsJson as List<dynamic>;
      return sectionsList
          .map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing sections: $e');
      return [];
    }
  }

  @override
  Future<List<SubjectEntity>> getSubjects() async {
    final id = await _getTenantId();
    final data = await supabase
        .from('subjects')
        .select()
        .eq('tenant_id', id) as List<dynamic>;

    return data
        .map((e) => SubjectEntity(
      id: e['id'] as String,
      tenantId: id,
      name: e['name'] as String,
    ))
        .toList();
  }

  @override
  Future<List<GradeEntity>> getGrades() async {
    final tenantIdValue = await _getTenantId();
    final data = await supabase
        .from('grades')
        .select()
        .eq('tenant_id', tenantIdValue)
        .eq('is_active', true)
        .order('level') as List<dynamic>;

    return data.map((e) => GradeEntity.fromJson(e)).toList();
  }

  @override
  Future<UserPermissionsEntity?> getUserPermissions() async {
    try {
      final userId = await _getUserId();
      final tenantIdValue = await _getTenantId();

      final data = await supabase
          .from('user_permissions')
          .select()
          .eq('user_id', userId)
          .eq('tenant_id', tenantIdValue)
          .maybeSingle();

      if (data == null) return null;
      return UserPermissionsEntity.fromJson(data);
    } catch (e) {
      print('Error fetching user permissions: $e');
      return null;
    }
  }

  @override
  Future<List<SubjectEntity>> getFilteredSubjects() async {
    // Check if user is admin FIRST
    final role = await _getUserRole();
    if (role == 'admin') {
      return await getSubjects(); // Return ALL subjects for admin
    }

    // Get user permissions for non-admin users
    final permissions = await getUserPermissions();
    if (permissions == null || !permissions.canCreatePapers) {
      return []; // No permissions, return empty list
    }

    // Get all subjects first
    final allSubjects = await getSubjects();

    // If no subject restrictions, return all
    if (permissions.subjectIds == null) return allSubjects;

    // Filter subjects based on permissions
    return allSubjects
        .where((subject) => permissions.subjectIds!.contains(subject.id))
        .toList();
  }

  @override
  Future<List<GradeEntity>> getFilteredGrades() async {
    // Check if user is admin FIRST
    final role = await _getUserRole();
    if (role == 'admin') {
      return await getGrades(); // Return ALL grades for admin
    }

    // Get user permissions for non-admin users
    final permissions = await getUserPermissions();
    if (permissions == null || !permissions.canCreatePapers) {
      return []; // No permissions, return empty list
    }

    // Get all grades first
    final allGrades = await getGrades();

    // If no grade restrictions, return all
    if (permissions.gradeLevels == null) return allGrades;

    // Filter grades based on permissions
    return allGrades
        .where((grade) => permissions.gradeLevels!.contains(grade.level))
        .toList();
  }

  @override
  Future<bool> canCreatePaper(String subjectId, int gradeLevel) async {
    try {
      // Check if user is admin - admins can create any paper
      final role = await _getUserRole();
      if (role == 'admin') return true;

      // Get user permissions
      final permissions = await getUserPermissions();
      if (permissions == null || !permissions.canCreatePapers) {
        return false;
      }

      // Check subject permission
      if (!permissions.canAccessSubject(subjectId)) {
        return false;
      }

      // Check grade level permission
      if (!permissions.canAccessGradeLevel(gradeLevel)) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking paper creation permissions: $e');
      return false;
    }
  }
}