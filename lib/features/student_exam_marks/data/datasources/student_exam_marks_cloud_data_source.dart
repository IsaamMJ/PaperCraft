import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../models/student_exam_marks_model.dart';

abstract class StudentExamMarksCloudDataSource {
  Future<List<StudentExamMarksModel>> getMarksForTimetableEntry(
    String examTimetableEntryId,
  );

  Future<StudentExamMarksModel?> getStudentMark(
    String studentId,
    String examTimetableEntryId,
  );

  Future<void> saveMarksAsDraft(List<Map<String, dynamic>> marksData);

  Future<void> submitMarks(List<Map<String, dynamic>> marksData);

  Future<List<StudentExamMarksModel>> autoCreateMarksForTimetableEntry({
    required String examTimetableEntryId,
    required String gradeId,
    required String section,
    required String tenantId,
  });
}

class StudentExamMarksCloudDataSourceImpl implements StudentExamMarksCloudDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'student_exam_marks';

  StudentExamMarksCloudDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<StudentExamMarksModel>> getMarksForTimetableEntry(
    String examTimetableEntryId,
  ) async {
    try {
      _logger.info(
        'Fetching marks for timetable entry: $examTimetableEntryId',
        category: LogCategory.system,
      );

      final response = await _apiClient.select<StudentExamMarksModel>(
        table: _tableName,
        fromJson: StudentExamMarksModel.fromSupabase,
        filters: {
          'exam_timetable_entry_id': examTimetableEntryId,
          'is_active': true,
        },
        selectColumns: '*, students(id, full_name, roll_number, email)',
      );

      if (response.isSuccess) {
        return response.data ?? [];
      } else {
        throw Exception(response.message);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error fetching marks for timetable entry',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<StudentExamMarksModel?> getStudentMark(
    String studentId,
    String examTimetableEntryId,
  ) async {
    try {
      final response = await _apiClient.selectSingle<StudentExamMarksModel>(
        table: _tableName,
        fromJson: StudentExamMarksModel.fromSupabase,
        filters: {
          'student_id': studentId,
          'exam_timetable_entry_id': examTimetableEntryId,
          'is_active': true,
        },
      );

      return response.isSuccess ? response.data : null;
    } catch (e) {
      _logger.error(
        'Error fetching student mark',
        category: LogCategory.system,
        error: e,
      );
      return null;
    }
  }

  @override
  Future<void> saveMarksAsDraft(List<Map<String, dynamic>> marksData) async {
    try {
      _logger.info(
        'Saving ${marksData.length} marks as draft',
        category: LogCategory.system,
      );

      // Update existing records - batch update would be ideal but Supabase doesn't support it
      // So we'll use individual updates
      for (final mark in marksData) {
        final response = await _apiClient.update<Map<String, dynamic>>(
          table: _tableName,
          data: {
            'total_marks': mark['total_marks'],
            'status': mark['status'],
            'remarks': mark['remarks'],
            'is_draft': true,
            'updated_at': DateTime.now().toIso8601String(),
          },
          filters: {
            'student_id': mark['student_id'],
            'exam_timetable_entry_id': mark['exam_timetable_entry_id'],
          },
          fromJson: (json) => json as Map<String, dynamic>,
        );

        if (!response.isSuccess) {
          throw Exception('Failed to save mark: ${response.message}');
        }
      }

      _logger.info(
        'Successfully saved marks as draft',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error saving marks as draft',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> submitMarks(List<Map<String, dynamic>> marksData) async {
    try {
      _logger.info(
        'Submitting ${marksData.length} marks',
        category: LogCategory.system,
      );

      // Update existing records to finalize marks
      for (final mark in marksData) {
        final response = await _apiClient.update<Map<String, dynamic>>(
          table: _tableName,
          data: {
            'total_marks': mark['total_marks'],
            'status': mark['status'],
            'remarks': mark['remarks'],
            'is_draft': false,
            'updated_at': DateTime.now().toIso8601String(),
          },
          filters: {
            'student_id': mark['student_id'],
            'exam_timetable_entry_id': mark['exam_timetable_entry_id'],
          },
          fromJson: (json) => json as Map<String, dynamic>,
        );

        if (!response.isSuccess) {
          throw Exception('Failed to submit mark: ${response.message}');
        }
      }

      _logger.info(
        'Successfully submitted marks',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error submitting marks',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<StudentExamMarksModel>> autoCreateMarksForTimetableEntry({
    required String examTimetableEntryId,
    required String gradeId,
    required String section,
    required String tenantId,
  }) async {
    try {
      _logger.info(
        'Auto-creating marks for timetable entry: $examTimetableEntryId',
        category: LogCategory.system,
      );

      // Get timetable entry to find subject_id
      final timetableResponse = await _apiClient.selectSingle<Map<String, dynamic>>(
        table: 'exam_timetable_entries',
        fromJson: (json) => json,
        filters: {
          'id': examTimetableEntryId,
        },
      );

      if (!timetableResponse.isSuccess || timetableResponse.data == null) {
        throw Exception('Timetable entry not found');
      }

      final subjectId = timetableResponse.data!['subject_id'];

      // Get teacher assigned to this subject for this grade/section
      final teacherResponse = await _apiClient.selectSingle<Map<String, dynamic>>(
        table: 'teacher_subjects',
        fromJson: (json) => json,
        filters: {
          'grade_id': gradeId,
          'subject_id': subjectId,
          'section': section,
          'tenant_id': tenantId,
          'is_active': true,
        },
      );

      if (!teacherResponse.isSuccess || teacherResponse.data == null) {
        throw Exception('No teacher assigned to this subject');
      }

      final teacherId = teacherResponse.data!['teacher_id'];

      // Get grade section ID
      final gradeSectionResponse = await _apiClient.selectSingle<Map<String, dynamic>>(
        table: 'grade_sections',
        fromJson: (json) => json,
        filters: {
          'grade_id': gradeId,
          'section_name': section,
          'tenant_id': tenantId,
        },
      );

      if (!gradeSectionResponse.isSuccess || gradeSectionResponse.data == null) {
        throw Exception('Grade section not found');
      }

      final gradeSectionId = gradeSectionResponse.data!['id'];

      // Get all active students in this grade/section
      final studentsResponse = await _apiClient.select<Map<String, dynamic>>(
        table: 'students',
        fromJson: (json) => json,
        filters: {
          'grade_section_id': gradeSectionId,
          'tenant_id': tenantId,
          'is_active': true,
        },
        selectColumns: 'id, full_name, roll_number, email',
      );

      if (!studentsResponse.isSuccess) {
        throw Exception('Failed to fetch students: ${studentsResponse.message}');
      }

      final students = studentsResponse.data ?? [];

      // Prepare batch insert data
      final now = DateTime.now();
      final marksDataList = students
          .map<Map<String, dynamic>>((student) => {
            'tenant_id': tenantId,
            'student_id': student['id'],
            'exam_timetable_entry_id': examTimetableEntryId,
            'total_marks': 0.0,
            'status': 'present',
            'remarks': null,
            'entered_by': teacherId,
            'is_draft': true,
            'is_active': true,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .toList();

      // Batch insert all marks
      if (marksDataList.isEmpty) {
        _logger.info(
          'No students to create marks for',
          category: LogCategory.system,
        );
        return [];
      }

      final insertResponse = await _apiClient.batchInsert<StudentExamMarksModel>(
        table: _tableName,
        dataList: marksDataList,
        fromJson: StudentExamMarksModel.fromSupabase,
      );

      if (!insertResponse.isSuccess) {
        throw Exception('Failed to create marks: ${insertResponse.message}');
      }

      final createdMarks = insertResponse.data ?? [];

      _logger.info(
        'Auto-created ${createdMarks.length} marks records',
        category: LogCategory.system,
      );

      return createdMarks;
    } catch (e, stackTrace) {
      _logger.error(
        'Error auto-creating marks',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
