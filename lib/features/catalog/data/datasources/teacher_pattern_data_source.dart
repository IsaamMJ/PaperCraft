// features/catalog/data/datasources/teacher_pattern_data_source.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_pattern_model.dart';

/// Data source for teacher patterns (Supabase operations)
class TeacherPatternDataSource {
  final SupabaseClient supabase;

  TeacherPatternDataSource(this.supabase);

  /// Get all patterns for a teacher and subject
  Future<List<TeacherPatternModel>> getPatternsByTeacherAndSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    final response = await supabase
        .from('teacher_patterns')
        .select()
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId)
        .order('last_used_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => TeacherPatternModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single pattern by ID
  Future<TeacherPatternModel?> getPatternById(String patternId) async {
    final response = await supabase
        .from('teacher_patterns')
        .select()
        .eq('id', patternId)
        .maybeSingle();

    if (response == null) return null;
    return TeacherPatternModel.fromJson(response as Map<String, dynamic>);
  }

  /// Find pattern with identical sections (for de-duplication)
  Future<TeacherPatternModel?> findPatternWithSameSections({
    required String teacherId,
    required String subjectId,
    required List<Map<String, dynamic>> sections,
  }) async {
    // Get all patterns for this teacher/subject
    final patterns = await getPatternsByTeacherAndSubject(
      teacherId: teacherId,
      subjectId: subjectId,
    );

    // Find pattern with identical sections
    for (final pattern in patterns) {
      if (_areSectionsIdentical(pattern.sections.map((s) => s.toJson()).toList(), sections)) {
        return pattern;
      }
    }

    return null;
  }

  /// Check if two section lists are identical
  bool _areSectionsIdentical(List<Map<String, dynamic>> sections1, List<Map<String, dynamic>> sections2) {
    if (sections1.length != sections2.length) return false;

    for (int i = 0; i < sections1.length; i++) {
      final s1 = sections1[i];
      final s2 = sections2[i];

      // Compare all relevant fields
      if (s1['name'] != s2['name'] ||
          s1['type'] != s2['type'] ||
          s1['questions'] != s2['questions'] ||
          s1['marks_per_question'] != s2['marks_per_question']) {
        return false;
      }
    }

    return true;
  }

  /// Create new pattern
  Future<TeacherPatternModel> createPattern(TeacherPatternModel pattern) async {
    // Don't include 'id' in insert - let database generate it
    final jsonData = pattern.toJson();
    jsonData.remove('id');

    final response = await supabase
        .from('teacher_patterns')
        .insert(jsonData)
        .select()
        .single();

    return TeacherPatternModel.fromJson(response as Map<String, dynamic>);
  }

  /// Update existing pattern (increment use count, update last used)
  Future<TeacherPatternModel> updatePattern({
    required String patternId,
    Map<String, dynamic>? updates,
  }) async {
    final response = await supabase
        .from('teacher_patterns')
        .update(updates ?? {})
        .eq('id', patternId)
        .select()
        .single();

    return TeacherPatternModel.fromJson(response as Map<String, dynamic>);
  }

  /// Increment use count and update last_used_at
  Future<TeacherPatternModel> incrementUseCount(String patternId) async {
    // First, get current use_count
    final current = await getPatternById(patternId);
    if (current == null) {
      throw Exception('Pattern not found');
    }

    // Then update with incremented value
    final response = await supabase
        .from('teacher_patterns')
        .update({
          'use_count': current.useCount + 1,
          'last_used_at': DateTime.now().toIso8601String(),
        })
        .eq('id', patternId)
        .select()
        .single();

    return TeacherPatternModel.fromJson(response as Map<String, dynamic>);
  }

  /// Delete pattern
  Future<void> deletePattern(String patternId) async {
    await supabase.from('teacher_patterns').delete().eq('id', patternId);
  }

  /// Get frequently used patterns (use_count > 3)
  Future<List<TeacherPatternModel>> getFrequentlyUsedPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 10,
  }) async {
    final response = await supabase
        .from('teacher_patterns')
        .select()
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId)
        .gt('use_count', 3)
        .order('use_count', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => TeacherPatternModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get recent patterns
  Future<List<TeacherPatternModel>> getRecentPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 10,
  }) async {
    final response = await supabase
        .from('teacher_patterns')
        .select()
        .eq('teacher_id', teacherId)
        .eq('subject_id', subjectId)
        .order('last_used_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) => TeacherPatternModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get all patterns by teacher (all subjects)
  Future<List<TeacherPatternModel>> getPatternsByTeacher({
    required String teacherId,
  }) async {
    final response = await supabase
        .from('teacher_patterns')
        .select()
        .eq('teacher_id', teacherId)
        .order('last_used_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => TeacherPatternModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
