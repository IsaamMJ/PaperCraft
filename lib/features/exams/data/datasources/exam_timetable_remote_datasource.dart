import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/exam_timetable.dart';
import '../../domain/entities/exam_timetable_entry.dart';

/// Abstract interface for exam timetable remote data operations
abstract class ExamTimetableRemoteDataSource {
  // ========== TIMETABLE CRUD ==========

  Future<ExamTimetable> createTimetable(ExamTimetable timetable);
  Future<ExamTimetable?> getTimetableById(String id);
  Future<List<ExamTimetable>> getTimetablesForTenant({
    required String tenantId,
    String? academicYear,
    String? status,
    bool activeOnly = true,
  });
  Future<void> updateTimetable(ExamTimetable timetable);
  Future<void> updateTimetableStatus({
    required String timetableId,
    required String status,
    DateTime? publishedAt,
  });
  Future<void> deleteTimetable(String timetableId);

  // ========== TIMETABLE ENTRIES CRUD ==========

  Future<ExamTimetableEntry> addTimetableEntry(ExamTimetableEntry entry);
  Future<List<ExamTimetableEntry>> getTimetableEntries(String timetableId);
  Future<List<ExamTimetableEntry>> getTimetableEntriesByGrade({
    required String timetableId,
    required String gradeId,
  });
  Future<ExamTimetableEntry?> getTimetableEntryById(String id);
  Future<void> updateTimetableEntry(ExamTimetableEntry entry);
  Future<void> removeTimetableEntry(String entryId);

  // ========== TIMETABLE ENTRY QUERIES ==========

  Future<int> countTimetableEntries(String timetableId);
  Future<bool> entryExists({
    required String timetableId,
    required String gradeId,
    required String subjectId,
    required String section,
  });
}

/// Implementation using Supabase
class ExamTimetableRemoteDataSourceImpl implements ExamTimetableRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExamTimetableRemoteDataSourceImpl({required this.supabaseClient});

  // ========== TIMETABLE CRUD ==========

  @override
  Future<ExamTimetable> createTimetable(ExamTimetable timetable) async {
    try {
      final response = await supabaseClient
          .from('exam_timetables')
          .insert(timetable.toJson())
          .select()
          .single();

      return ExamTimetable.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ExamTimetable?> getTimetableById(String id) async {
    try {
      final response = await supabaseClient
          .from('exam_timetables')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return ExamTimetable.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ExamTimetable>> getTimetablesForTenant({
    required String tenantId,
    String? academicYear,
    String? status,
    bool activeOnly = true,
  }) async {
    try {
      var query = supabaseClient
          .from('exam_timetables')
          .select()
          .eq('tenant_id', tenantId);

      if (academicYear != null) {
        query = query.eq('academic_year', academicYear);
      }

      if (status != null) {
        query = query.eq('status', status);
      }

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('created_at', ascending: false);

      return List<ExamTimetable>.from(
        response.map((json) => ExamTimetable.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateTimetable(ExamTimetable timetable) async {
    try {
      await supabaseClient
          .from('exam_timetables')
          .update(timetable.toJson())
          .eq('id', timetable.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateTimetableStatus({
    required String timetableId,
    required String status,
    DateTime? publishedAt,
  }) async {
    try {
      final data = {
        'status': status,
        if (publishedAt != null) 'published_at': publishedAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabaseClient
          .from('exam_timetables')
          .update(data)
          .eq('id', timetableId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteTimetable(String timetableId) async {
    try {
      await supabaseClient
          .from('exam_timetables')
          .update({'is_active': false})
          .eq('id', timetableId);
    } catch (e) {
      rethrow;
    }
  }

  // ========== TIMETABLE ENTRIES CRUD ==========

  @override
  Future<ExamTimetableEntry> addTimetableEntry(ExamTimetableEntry entry) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .insert(entry.toJson())
          .select()
          .single();

      return ExamTimetableEntry.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ExamTimetableEntry>> getTimetableEntries(String timetableId) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', timetableId)
          .eq('is_active', true)
          .order('exam_date', ascending: true);

      return List<ExamTimetableEntry>.from(
        response.map((json) => ExamTimetableEntry.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ExamTimetableEntry>> getTimetableEntriesByGrade({
    required String timetableId,
    required String gradeId,
  }) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('timetable_id', timetableId)
          .eq('grade_id', gradeId)
          .eq('is_active', true)
          .order('exam_date', ascending: true);

      return List<ExamTimetableEntry>.from(
        response.map((json) => ExamTimetableEntry.fromJson(json as Map<String, dynamic>)),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ExamTimetableEntry?> getTimetableEntryById(String id) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return ExamTimetableEntry.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateTimetableEntry(ExamTimetableEntry entry) async {
    try {
      await supabaseClient
          .from('exam_timetable_entries')
          .update(entry.toJson())
          .eq('id', entry.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> removeTimetableEntry(String entryId) async {
    try {
      await supabaseClient
          .from('exam_timetable_entries')
          .update({'is_active': false})
          .eq('id', entryId);
    } catch (e) {
      rethrow;
    }
  }

  // ========== TIMETABLE ENTRY QUERIES ==========

  @override
  Future<int> countTimetableEntries(String timetableId) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .select('id')
          .eq('timetable_id', timetableId)
          .eq('is_active', true);

      return response.length;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> entryExists({
    required String timetableId,
    required String gradeId,
    required String subjectId,
    required String section,
  }) async {
    try {
      final response = await supabaseClient
          .from('exam_timetable_entries')
          .select('id')
          .eq('timetable_id', timetableId)
          .eq('grade_id', gradeId)
          .eq('subject_id', subjectId)
          .eq('section', section)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      rethrow;
    }
  }
}
