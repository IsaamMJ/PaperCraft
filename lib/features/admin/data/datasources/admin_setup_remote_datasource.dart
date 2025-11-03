import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/domain/errors/failures.dart';

/// Abstract interface for admin setup remote data source
abstract class AdminSetupRemoteDataSource {
  /// Get all available grades for a tenant
  Future<List<int>> getAvailableGrades(String tenantId);

  /// Get subject suggestions from catalog for a grade
  /// Filters by min_grade <= gradeNumber <= max_grade
  Future<List<String>> getSubjectSuggestions(int gradeNumber);

  /// Get all subjects already in tenant
  Future<List<String>> getTenantSubjects(String tenantId);

  /// Create grades for the tenant
  Future<void> createGrades({
    required String tenantId,
    required List<int> gradeNumbers,
  });

  /// Create sections for a grade
  Future<void> createSections({
    required String tenantId,
    required int gradeNumber,
    required List<String> sections,
  });

  /// Create/link subjects to a grade in tenant
  Future<void> createSubjectsForGrade({
    required String tenantId,
    required int gradeNumber,
    required List<String> subjectNames,
  });

  /// Mark tenant as initialized
  Future<void> markTenantInitialized(String tenantId);

  /// Update tenant details (name, address)
  Future<void> updateTenantDetails({
    required String tenantId,
    required String name,
    required String? address,
  });

  /// Get complete setup summary
  Future<Map<String, dynamic>> getSetupSummary(String tenantId);
}

/// Implementation using Supabase
class AdminSetupRemoteDataSourceImpl implements AdminSetupRemoteDataSource {
  final SupabaseClient supabaseClient;

  AdminSetupRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<int>> getAvailableGrades(String tenantId) async {
    try {
      final response = await supabaseClient
          .from('grades')
          .select('grade_number')
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      final grades = (response as List)
          .map((g) => g['grade_number'] as int)
          .toList();

      grades.sort();
      return grades;
    } catch (e) {
      throw ServerFailure('Failed to fetch grades: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getSubjectSuggestions(int gradeNumber) async {
    try {
      final response = await supabaseClient
          .from('subject_catalog')
          .select('subject_name')
          .lte('min_grade', gradeNumber)
          .gte('max_grade', gradeNumber)
          .eq('is_active', true);

      final subjects = (response as List)
          .map((s) => s['subject_name'] as String)
          .toList();

      subjects.sort();
      return subjects;
    } catch (e) {
      throw ServerFailure('Failed to fetch subject suggestions: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getTenantSubjects(String tenantId) async {
    try {
      final response = await supabaseClient
          .from('subjects')
          .select('subject_name')
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      final subjects = (response as List)
          .map((s) => s['subject_name'] as String)
          .toSet()
          .toList();

      subjects.sort();
      return subjects;
    } catch (e) {
      throw ServerFailure('Failed to fetch tenant subjects: ${e.toString()}');
    }
  }

  @override
  Future<void> createGrades({
    required String tenantId,
    required List<int> gradeNumbers,
  }) async {
    try {
      // First, delete any existing grades for this tenant to avoid duplicates
      await supabaseClient
          .from('grades')
          .delete()
          .eq('tenant_id', tenantId);

      // Now insert the new grades
      final gradesToInsert = gradeNumbers.map((gradeNum) => {
        'tenant_id': tenantId,
        'grade_number': gradeNum,
        'is_active': true,
      }).toList();

      await supabaseClient
          .from('grades')
          .insert(gradesToInsert, defaultToNull: false);
    } catch (e) {
      throw ServerFailure('Failed to create grades: ${e.toString()}');
    }
  }

  @override
  Future<void> createSections({
    required String tenantId,
    required int gradeNumber,
    required List<String> sections,
  }) async {
    try {
      // First, get the grade_id for this grade
      final gradeResponse = await supabaseClient
          .from('grades')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('grade_number', gradeNumber)
          .eq('is_active', true)
          .single();

      final gradeId = gradeResponse['id'] as String;

      // Delete existing sections for this grade
      await supabaseClient
          .from('grade_sections')
          .delete()
          .eq('grade_id', gradeId);

      // Insert fresh sections
      final sectionsToInsert = sections.map((section) => {
        'tenant_id': tenantId,
        'grade_id': gradeId,
        'section_name': section,
        'is_active': true,
      }).toList();

      await supabaseClient
          .from('grade_sections')
          .insert(sectionsToInsert, defaultToNull: false);
    } catch (e) {
      throw ServerFailure('Failed to create sections: ${e.toString()}');
    }
  }

  @override
  Future<void> createSubjectsForGrade({
    required String tenantId,
    required int gradeNumber,
    required List<String> subjectNames,
  }) async {
    try {
      // Delete existing subjects for this tenant
      // Note: subjects table doesn't have grade_number, it only stores tenant-subject links
      await supabaseClient
          .from('subjects')
          .delete()
          .eq('tenant_id', tenantId);

      // For each subject name, find the catalog_subject_id and insert
      final subjectsToInsert = <Map<String, dynamic>>[];

      for (final subjectName in subjectNames) {
        // Find the catalog_subject_id for this subject name
        final catalogResponse = await supabaseClient
            .from('subject_catalog')
            .select('id')
            .eq('subject_name', subjectName)
            .eq('is_active', true)
            .single();

        final catalogSubjectId = catalogResponse['id'] as String;

        subjectsToInsert.add({
          'tenant_id': tenantId,
          'catalog_subject_id': catalogSubjectId,
          'is_active': true,
        });
      }

      if (subjectsToInsert.isNotEmpty) {
        await supabaseClient
            .from('subjects')
            .insert(subjectsToInsert, defaultToNull: false);
      }
    } catch (e) {
      throw ServerFailure('Failed to create subjects: ${e.toString()}');
    }
  }

  @override
  Future<void> updateTenantDetails({
    required String tenantId,
    required String name,
    required String? address,
  }) async {
    try {
      final updateData = {
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
      };

      await supabaseClient
          .from('tenants')
          .update(updateData)
          .eq('id', tenantId);
    } catch (e) {
      throw ServerFailure(
          'Failed to update tenant details: ${e.toString()}');
    }
  }

  @override
  Future<void> markTenantInitialized(String tenantId) async {
    try {
      // Mark tenant as initialized
      // This flag is used to determine if first-time onboarding is complete
      await supabaseClient
          .from('tenants')
          .update({'is_initialized': true})
          .eq('id', tenantId);
    } catch (e) {
      throw ServerFailure('Failed to mark tenant as initialized: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getSetupSummary(String tenantId) async {
    try {
      // Get grades
      final gradesResponse = await supabaseClient
          .from('grades')
          .select('grade_number')
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      final grades = (gradesResponse as List)
          .map((g) => g['grade_number'] as int)
          .toList();

      grades.sort();

      // Get sections per grade
      final sectionsResponse = await supabaseClient
          .from('grade_sections')
          .select('grade_id, section_name')
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      final Map<int, List<String>> sectionsPerGrade = {};
      for (final section in sectionsResponse) {
        final gradeId = section['grade_id'];
        final sectionName = section['section_name'];

        // Get grade number for this grade_id
        final gradeResponse = await supabaseClient
            .from('grades')
            .select('grade_number')
            .eq('id', gradeId)
            .single();

        final gradeNum = gradeResponse['grade_number'] as int;
        sectionsPerGrade.putIfAbsent(gradeNum, () => []);
        sectionsPerGrade[gradeNum]!.add(sectionName);
      }

      // Get subjects per grade
      final subjectsResponse = await supabaseClient
          .from('subjects')
          .select('subject_name, grade_number')
          .eq('tenant_id', tenantId)
          .eq('is_active', true);

      final Map<int, List<String>> subjectsPerGrade = {};
      for (final subject in subjectsResponse) {
        final gradeNum = subject['grade_number'] as int?;
        if (gradeNum != null) {
          subjectsPerGrade.putIfAbsent(gradeNum, () => []);
          subjectsPerGrade[gradeNum]!.add(subject['subject_name']);
        }
      }

      return {
        'grades': grades,
        'sections_per_grade': sectionsPerGrade,
        'subjects_per_grade': subjectsPerGrade,
      };
    } catch (e) {
      throw ServerFailure('Failed to fetch setup summary: ${e.toString()}');
    }
  }
}
