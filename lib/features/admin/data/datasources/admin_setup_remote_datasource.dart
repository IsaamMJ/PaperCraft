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
      // First, deactivate all existing grades for this tenant
      await supabaseClient
          .from('grades')
          .update({'is_active': false})
          .eq('tenant_id', tenantId);

      // UPSERT: For each grade, update if exists (reactivate), insert if not
      // This handles the unique constraint properly
      final gradeData = gradeNumbers.map((gradeNum) => {
        'tenant_id': tenantId,
        'grade_number': gradeNum,
        'is_active': true,
      }).toList();

      // Upsert with conflict on (tenant_id, grade_number) unique constraint
      await supabaseClient
          .from('grades')
          .upsert(gradeData, onConflict: 'tenant_id,grade_number');
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

      // Deactivate all existing sections for this grade
      await supabaseClient
          .from('grade_sections')
          .update({'is_active': false})
          .eq('grade_id', gradeId);

      // UPSERT: For each section, update if exists (reactivate), insert if not
      final sectionsToUpsert = sections.map((section) => {
        'tenant_id': tenantId,
        'grade_id': gradeId,
        'section_name': section,
        'is_active': true,
      }).toList();

      // Upsert with conflict on (tenant_id, grade_id, section_name) unique constraint
      await supabaseClient
          .from('grade_sections')
          .upsert(sectionsToUpsert, onConflict: 'tenant_id,grade_id,section_name');
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
      // Step 1: Get the grade ID for this grade number
      final gradeResponse = await supabaseClient
          .from('grades')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('grade_number', gradeNumber)
          .single();

      final gradeId = gradeResponse['id'] as String;

      // Step 2: Get all sections for this grade
      final sectionsResponse = await supabaseClient
          .from('grade_sections')
          .select('section_name')
          .eq('grade_id', gradeId)
          .eq('is_active', true);

      final sections = (sectionsResponse as List)
          .map((s) => s['section_name'] as String)
          .toList();

      // Step 3: Mark existing grade-section-subject mappings as inactive for this grade
      // SOFT DELETE: Preserves data history and avoids FK constraint issues
      await supabaseClient
          .from('grade_section_subject')
          .update({'is_offered': false})
          .eq('grade_id', gradeId);

      // Step 4: For each subject name, find the subject ID and create mappings for all sections
      final gradeSubjectsToInsert = <Map<String, dynamic>>[];

      for (final subjectName in subjectNames) {
        // Find the catalog_subject_id for this subject name
        final catalogResponse = await supabaseClient
            .from('subject_catalog')
            .select('id')
            .eq('subject_name', subjectName)
            .eq('is_active', true)
            .single();

        final catalogSubjectId = catalogResponse['id'] as String;

        // Check if subject already exists in subjects table for this tenant
        final subjectsResponse = await supabaseClient
            .from('subjects')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('catalog_subject_id', catalogSubjectId);

        String subjectId;
        if ((subjectsResponse as List).isNotEmpty) {
          // Subject already exists, use its ID
          subjectId = subjectsResponse[0]['id'] as String;
        } else {
          // Subject doesn't exist, create it
          final newSubjectResponse = await supabaseClient
              .from('subjects')
              .insert({
                'tenant_id': tenantId,
                'catalog_subject_id': catalogSubjectId,
                'is_active': true,
              }, defaultToNull: false)
              .select()
              .single();

          subjectId = newSubjectResponse['id'] as String;
        }

        // Create grade-section-subject mapping for each section
        for (final section in sections) {
          gradeSubjectsToInsert.add({
            'tenant_id': tenantId,
            'grade_id': gradeId,
            'section': section,
            'subject_id': subjectId,
            'is_offered': true,
            'display_order': 0,
          });
        }
      }

      // Step 5: UPSERT all grade-section-subject mappings
      // Update if exists (reactivate), insert if not
      if (gradeSubjectsToInsert.isNotEmpty) {
        await supabaseClient
            .from('grade_section_subject')
            .upsert(
              gradeSubjectsToInsert,
              onConflict: 'tenant_id,grade_id,section,subject_id',
            );
      }
    } catch (e) {
      throw ServerFailure('Failed to create subjects for grade: ${e.toString()}');
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

      // Get subjects per grade (from grade_section_subject table)
      final subjectsResponse = await supabaseClient
          .from('grade_section_subject')
          .select('*, grades(grade_number), subjects(id, catalog_subject_id)')
          .eq('tenant_id', tenantId)
          .eq('is_offered', true);

      // Collect catalog subject IDs for lookup
      final catalogSubjectIds = <String>{};
      for (final gradeSectionSubject in subjectsResponse as List) {
        final subjectData = gradeSectionSubject['subjects'] as Map<String, dynamic>?;
        final catalogSubjectId = subjectData?['catalog_subject_id'] as String?;
        if (catalogSubjectId != null) {
          catalogSubjectIds.add(catalogSubjectId);
        }
      }

      // Fetch subject names from catalog
      final catalogSubjectMap = <String, String>{};
      if (catalogSubjectIds.isNotEmpty) {
        try {
          final catalogData = await supabaseClient
              .from('subject_catalog')
              .select('id, subject_name')
              .inFilter('id', catalogSubjectIds.toList());

          for (final catalog in catalogData as List) {
            final id = catalog['id'] as String;
            final name = catalog['subject_name'] as String;
            catalogSubjectMap[id] = name;
          }
        } catch (e) {
          // Continue without catalog data
        }
      }

      final Map<int, List<String>> subjectsPerGrade = {};
      for (final gradeSectionSubject in subjectsResponse as List) {
        try {
          final gradeData = gradeSectionSubject['grades'] as Map<String, dynamic>?;
          final gradeNum = gradeData?['grade_number'] as int?;

          final subjectData = gradeSectionSubject['subjects'] as Map<String, dynamic>?;
          final catalogSubjectId = subjectData?['catalog_subject_id'] as String?;
          final subjectName = catalogSubjectId != null ? catalogSubjectMap[catalogSubjectId] : null;

          if (gradeNum != null && subjectName != null) {
            subjectsPerGrade.putIfAbsent(gradeNum, () => []);
            // Only add if not already in the list (to avoid duplicates per section)
            if (!subjectsPerGrade[gradeNum]!.contains(subjectName)) {
              subjectsPerGrade[gradeNum]!.add(subjectName);
            }
          }
        } catch (e) {
          // Skip on error, continue with next subject
          continue;
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
