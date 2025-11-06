import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/grade_subject_model.dart';

abstract class GradeSubjectDataSource {
  Future<List<GradeSubjectModel>> getSubjectsForGradeSection(
    String tenantId,
    String gradeId,
    String sectionId,
  );

  Future<GradeSubjectModel?> getGradeSubjectById(String id);

  Future<GradeSubjectModel> addSubjectToSection(GradeSubjectModel model);

  Future<void> removeSubjectFromSection(String id);

  Future<void> updateGradeSubject(GradeSubjectModel model);

  Future<List<GradeSubjectModel>> getSubjectsForGrade(
    String tenantId,
    String gradeId,
  );

  Future<List<GradeSubjectModel>> addMultipleSubjectsToSection(
    String tenantId,
    String gradeId,
    String sectionId,
    List<String> subjectIds,
  );

  Future<void> clearSubjectsFromSection(
    String tenantId,
    String gradeId,
    String sectionId,
  );
}

class GradeSubjectDataSourceImpl implements GradeSubjectDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  GradeSubjectDataSourceImpl(this._supabase, this._logger);

  @override
  Future<List<GradeSubjectModel>> getSubjectsForGradeSection(
    String tenantId,
    String gradeId,
    String sectionId,
  ) async {
    try {
      print('📚 [DS] Getting subjects for Grade=$gradeId, Section=$sectionId');

      final response = await _supabase
          .from('grade_section_subject')
          .select()
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('section', sectionId) // section is text, not UUID
          .eq('is_offered', true)
          .order('display_order');

      final result = (response as List)
          .map((json) => GradeSubjectModel.fromJson(json as Map<String, dynamic>))
          .toList();

      print('✅ [DS] Loaded ${result.length} subjects');
      return result;
    } catch (e, stackTrace) {
      print('❌ [DS] Error getting subjects: $e');
      _logger.error(
        'Failed to fetch subjects for grade-section',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<GradeSubjectModel?> getGradeSubjectById(String id) async {
    try {
      final response = await _supabase
          .from('grade_section_subject')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return GradeSubjectModel.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch grade subject by ID',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<GradeSubjectModel> addSubjectToSection(GradeSubjectModel model) async {
    try {
      print('➕ [DS] Adding subject ${model.subjectId} to section ${model.section}');

      final data = {
        'id': model.id,
        'tenant_id': model.tenantId,
        'grade_id': model.gradeId,
        'section': model.section, // section is text
        'subject_id': model.subjectId,
        'display_order': model.displayOrder,
        'is_offered': true, // changed from is_active
      };

      final response = await _supabase
          .from('grade_section_subject')
          .insert(data)
          .select()
          .single();

      print('✅ [DS] Subject added successfully');
      return GradeSubjectModel.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ [DS] Error adding subject: $e');
      _logger.error(
        'Failed to add subject to section',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeSubjectFromSection(String id) async {
    try {
      print('🗑️ [DS] Removing subject: $id');

      await _supabase
          .from('grade_section_subject')
          .update({'is_offered': false})
          .eq('id', id);

      print('✅ [DS] Subject removed successfully');
    } catch (e, stackTrace) {
      print('❌ [DS] Error removing subject: $e');
      _logger.error(
        'Failed to remove subject from section',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateGradeSubject(GradeSubjectModel model) async {
    try {
      print('✏️ [DS] Updating subject: ${model.id}');

      await _supabase
          .from('grade_section_subject')
          .update(model.toJson())
          .eq('id', model.id);

      print('✅ [DS] Subject updated successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update grade subject',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<GradeSubjectModel>> getSubjectsForGrade(
    String tenantId,
    String gradeId,
  ) async {
    try {
      final response = await _supabase
          .from('grade_section_subject')
          .select()
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('is_offered', true)
          .order('section')
          .order('display_order');

      final result = (response as List)
          .map((json) => GradeSubjectModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch subjects for grade',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<GradeSubjectModel>> addMultipleSubjectsToSection(
    String tenantId,
    String gradeId,
    String sectionId,
    List<String> subjectIds,
  ) async {
    try {
      print('➕ [DS] Adding ${subjectIds.length} subjects to section $sectionId');

      final now = DateTime.now();
      final data = subjectIds.asMap().entries.map((entry) {
        return {
          'id': const Uuid().v4(),
          'tenant_id': tenantId,
          'grade_id': gradeId,
          'section': sectionId, // section is text
          'subject_id': entry.value,
          'display_order': entry.key + 1,
          'is_offered': true, // changed from is_active
        };
      }).toList();

      final response = await _supabase
          .from('grade_section_subject')
          .insert(data)
          .select();

      final result = (response as List)
          .map((json) => GradeSubjectModel.fromJson(json as Map<String, dynamic>))
          .toList();

      print('✅ [DS] Added ${result.length} subjects');
      return result;
    } catch (e, stackTrace) {
      print('❌ [DS] Error adding multiple subjects: $e');
      _logger.error(
        'Failed to add multiple subjects',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> clearSubjectsFromSection(
    String tenantId,
    String gradeId,
    String sectionId,
  ) async {
    try {
      print('🧹 [DS] Clearing all subjects from section $sectionId');

      await _supabase
          .from('grade_section_subject')
          .update({'is_offered': false})
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('section', sectionId); // section is text

      print('✅ [DS] Subjects cleared');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear subjects from section',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
