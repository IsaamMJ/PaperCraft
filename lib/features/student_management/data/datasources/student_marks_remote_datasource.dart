import 'package:papercraft/features/student_management/data/models/student_exam_marks_model.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote student marks data operations
abstract class StudentMarksRemoteDataSource {
  /// Add or update marks for a student
  Future<StudentExamMarksModel> addExamMarks(StudentExamMarksModel marks);

  /// Get all marks for an exam
  Future<List<StudentExamMarksModel>> getExamMarks(String examTimetableEntryId);

  /// Get marks for a specific student in an exam
  Future<StudentExamMarksModel?> getStudentExamMarks({
    required String studentId,
    required String examTimetableEntryId,
  });

  /// Get draft marks for an exam
  Future<List<StudentExamMarksModel>> getDraftMarks(String examTimetableEntryId);

  /// Submit marks (set is_draft = false)
  Future<void> submitMarks(String examTimetableEntryId);

  /// Update marks
  Future<StudentExamMarksModel> updateMarks(StudentExamMarksModel marks);

  /// Bulk insert marks
  Future<List<StudentExamMarksModel>> bulkInsertMarks(List<StudentExamMarksModel> marksList);

  /// Soft delete marks
  Future<void> deleteMarks({
    required String studentId,
    required String examTimetableEntryId,
  });

  /// Get marks statistics
  Future<Map<String, dynamic>> getMarksStatistics(String examTimetableEntryId);

  /// Check if marks are submitted
  Future<bool> areMarksSubmitted(String examTimetableEntryId);

  /// Get marks by teacher
  Future<List<StudentExamMarksModel>> getMarksByTeacher(String teacherId);

  /// Get marks by status
  Future<List<StudentExamMarksModel>> getMarksByStatus({
    required String examTimetableEntryId,
    required String status,
  });
}

/// Implementation using Supabase
class StudentMarksRemoteDataSourceImpl implements StudentMarksRemoteDataSource {
  final SupabaseClient supabaseClient;

  StudentMarksRemoteDataSourceImpl({required this.supabaseClient});

  static const String _tableName = 'student_exam_marks';

  @override
  Future<StudentExamMarksModel> addExamMarks(StudentExamMarksModel marks) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .insert(marks.toJsonRequest())
          .select()
          .single();

      return StudentExamMarksModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> getExamMarks(
    String examTimetableEntryId,
  ) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => StudentExamMarksModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<StudentExamMarksModel?> getStudentExamMarks({
    required String studentId,
    required String examTimetableEntryId,
  }) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('student_id', studentId)
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return StudentExamMarksModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> getDraftMarks(
    String examTimetableEntryId,
  ) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_draft', true)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => StudentExamMarksModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> submitMarks(String examTimetableEntryId) async {
    try {
      await supabaseClient
          .from(_tableName)
          .update({'is_draft': false})
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_active', true);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<StudentExamMarksModel> updateMarks(StudentExamMarksModel marks) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .update(marks.toJsonRequest())
          .eq('id', marks.id)
          .select()
          .single();

      return StudentExamMarksModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> bulkInsertMarks(
    List<StudentExamMarksModel> marksList,
  ) async {
    try {
      if (marksList.isEmpty) return [];

      final jsonList = marksList.map((m) => m.toJsonRequest()).toList();

      final response = await supabaseClient
          .from(_tableName)
          .insert(jsonList)
          .select();

      return (response as List<dynamic>)
          .map((json) => StudentExamMarksModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteMarks({
    required String studentId,
    required String examTimetableEntryId,
  }) async {
    try {
      await supabaseClient
          .from(_tableName)
          .update({'is_active': false})
          .eq('student_id', studentId)
          .eq('exam_timetable_entry_id', examTimetableEntryId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getMarksStatistics(
    String examTimetableEntryId,
  ) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('total_marks, status')
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_active', true);

      final marks = response as List<dynamic>;

      if (marks.isEmpty) {
        return {
          'average': 0.0,
          'highest': 0.0,
          'lowest': 0.0,
          'total_count': 0,
          'present_count': 0,
          'absent_count': 0,
        };
      }

      final marksList = marks
          .where((m) => (m['status'] as String?) == 'present')
          .map((m) => (m['total_marks'] as num).toDouble())
          .toList();

      if (marksList.isEmpty) {
        return {
          'average': 0.0,
          'highest': 0.0,
          'lowest': 0.0,
          'total_count': marks.length,
          'present_count': 0,
          'absent_count': marks.length,
        };
      }

      final average = marksList.fold<double>(0, (a, b) => a + b) / marksList.length;
      final highest = marksList.reduce((a, b) => a > b ? a : b);
      final lowest = marksList.reduce((a, b) => a < b ? a : b);

      final absentCount = marks
          .where((m) => (m['status'] as String?) != 'present')
          .length;

      return {
        'average': average,
        'highest': highest,
        'lowest': lowest,
        'total_count': marks.length,
        'present_count': marksList.length,
        'absent_count': absentCount,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> areMarksSubmitted(String examTimetableEntryId) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('id')
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('is_draft', false)
          .eq('is_active', true)
          .limit(1);

      return (response as List<dynamic>).isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> getMarksByTeacher(String teacherId) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('entered_by', teacherId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => StudentExamMarksModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> getMarksByStatus({
    required String examTimetableEntryId,
    required String status,
  }) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('exam_timetable_entry_id', examTimetableEntryId)
          .eq('status', status)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => StudentExamMarksModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
