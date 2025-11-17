import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/grade_section.dart';

/// Abstract interface for grade section remote data operations
abstract class GradeSectionRemoteDataSource {
  /// Fetch all sections for a tenant, optionally filtered by grade
  Future<List<GradeSection>> getGradeSections({
    required String tenantId,
    String? gradeId,
    bool activeOnly = true,
  });

  /// Fetch a single section by ID
  Future<GradeSection?> getGradeSectionById(String id);

  /// Create a new grade section
  Future<GradeSection> createGradeSection(GradeSection section);

  /// Update an existing grade section
  Future<void> updateGradeSection(GradeSection section);

  /// Soft delete a grade section (set is_active = false)
  Future<void> deleteGradeSection(String id);

  /// Get all unique grades that have sections defined
  Future<List<String>> getGradesWithSections({
    required String tenantId,
    bool activeOnly = true,
  });
}

/// Implementation using Supabase
class GradeSectionRemoteDataSourceImpl implements GradeSectionRemoteDataSource {
  final SupabaseClient supabaseClient;

  GradeSectionRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<GradeSection>> getGradeSections({
    required String tenantId,
    String? gradeId,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('grade_sections')
          .select()
          .eq('tenant_id', tenantId);

      if (gradeId != null) {
        query = query.eq('grade_id', gradeId);
      }

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('display_order', ascending: true);

      final sections = List<GradeSection>.from(
        response.map((json) => GradeSection.fromJson(json as Map<String, dynamic>)),
      );

      // Debug: Show we got data from Supabase database
      if (gradeId != null) {
      }

      return sections;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<GradeSection?> getGradeSectionById(String id) async {
    try {
      final response = await supabaseClient
          .from('grade_sections')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return GradeSection.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<GradeSection> createGradeSection(GradeSection section) async {
    try {
      final response = await supabaseClient
          .from('grade_sections')
          .insert(section.toJson())
          .select()
          .single();

      return GradeSection.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateGradeSection(GradeSection section) async {
    try {
      await supabaseClient
          .from('grade_sections')
          .update(section.toJson())
          .eq('id', section.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteGradeSection(String id) async {
    try {
      await supabaseClient
          .from('grade_sections')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<String>> getGradesWithSections({
    required String tenantId,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('grade_sections')
          .select('grade_id')
          .eq('tenant_id', tenantId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query;

      // Extract unique grade IDs using a Set
      final gradeIds = <String>{};
      for (final item in response) {
        final gradeId = item['grade_id'] as String?;
        if (gradeId != null) {
          gradeIds.add(gradeId);
        }
      }

      return gradeIds.toList()..sort();
    } catch (e) {
      rethrow;
    }
  }
}
