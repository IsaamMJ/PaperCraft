import 'package:papercraft/features/student_management/data/models/student_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract interface for remote student data operations
abstract class StudentRemoteDataSource {
  /// Add a new student
  Future<StudentModel> addStudent(StudentModel student);

  /// Get all active students for a grade section
  Future<List<StudentModel>> getStudentsByGradeSection(String gradeSectionId);

  /// Get a single student by ID
  Future<StudentModel?> getStudentById(String studentId);

  /// Get all active students for the current tenant
  Future<List<StudentModel>> getAllActiveStudents();

  /// Update student information
  Future<StudentModel> updateStudent(StudentModel student);

  /// Soft delete a student
  Future<void> deleteStudent(String studentId);

  /// Bulk insert students
  Future<List<StudentModel>> bulkInsertStudents(List<StudentModel> students);

  /// Check if student exists with roll number in grade section
  Future<bool> studentExists({
    required String gradeSectionId,
    required String rollNumber,
  });

  /// Get student count for a grade section
  Future<int> getStudentCountByGradeSection(String gradeSectionId);

  /// Get students with pagination
  Future<List<StudentModel>> getStudentsWithPagination({
    required int offset,
    required int limit,
    String? gradeSectionId,
  });
}

/// Implementation using Supabase
class StudentRemoteDataSourceImpl implements StudentRemoteDataSource {
  final SupabaseClient supabaseClient;

  StudentRemoteDataSourceImpl({required this.supabaseClient});

  static const String _tableName = 'students';

  @override
  Future<StudentModel> addStudent(StudentModel student) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .insert(student.toJsonRequest())
          .select()
          .single();

      return StudentModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentModel>> getStudentsByGradeSection(
    String gradeSectionId,
  ) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('''
            *,
            grade_sections(
              section_name,
              grade_id,
              grades(grade_number)
            )
          ''')
          .eq('grade_section_id', gradeSectionId)
          .eq('is_active', true)
          .order('roll_number', ascending: true);

      return (response as List<dynamic>)
          .map((json) => _mapJsonToStudent(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select()
          .eq('id', studentId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return StudentModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentModel>> getAllActiveStudents() async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('''
            *,
            grade_sections(
              section_name,
              grade_id,
              grades(grade_number)
            )
          ''')
          .eq('is_active', true)
          .order('roll_number', ascending: true);

      return (response as List<dynamic>)
          .map((json) => _mapJsonToStudent(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Helper method to map JSON response with nested grade_sections data
  StudentModel _mapJsonToStudent(Map<String, dynamic> json) {
    // Extract grade and section info from nested response
    int? gradeNumber;
    String? sectionName;

    final gradeSections = json['grade_sections'] as Map<String, dynamic>?;
    if (gradeSections != null) {
      sectionName = gradeSections['section_name'] as String?;
      final grades = gradeSections['grades'] as Map<String, dynamic>?;
      if (grades != null) {
        gradeNumber = grades['grade_number'] as int?;
      }
    }

    return StudentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      gradeSectionId: json['grade_section_id'] as String,
      rollNumber: json['roll_number'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      academicYear: json['academic_year'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      gradeNumber: gradeNumber,
      sectionName: sectionName,
    );
  }

  @override
  Future<StudentModel> updateStudent(StudentModel student) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .update(student.toJsonRequest())
          .eq('id', student.id)
          .select()
          .single();

      return StudentModel.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    try {
      await supabaseClient
          .from(_tableName)
          .update({'is_active': false})
          .eq('id', studentId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentModel>> bulkInsertStudents(List<StudentModel> students) async {
    try {
      print('[DEBUG DS] bulkInsertStudents called with ${students.length} students');
      if (students.isEmpty) {
        print('[DEBUG DS] No students to insert');
        return [];
      }

      final jsonList = students.map((s) => s.toJsonRequest()).toList();
      print('[DEBUG DS] Converted to JSON, first student: ${jsonList.first}');

      final response = await supabaseClient
          .from(_tableName)
          .insert(jsonList)
          .select('''
            *,
            grade_sections(
              section_name,
              grade_id,
              grades(grade_number)
            )
          ''');

      print('[DEBUG DS] Insert response received: ${(response as List).length} items');
      return (response as List<dynamic>)
          .map((json) => _mapJsonToStudent(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[DEBUG DS] Exception in bulkInsertStudents: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<bool> studentExists({
    required String gradeSectionId,
    required String rollNumber,
  }) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('id')
          .eq('grade_section_id', gradeSectionId)
          .eq('roll_number', rollNumber)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getStudentCountByGradeSection(String gradeSectionId) async {
    try {
      final response = await supabaseClient
          .from(_tableName)
          .select('id')
          .eq('grade_section_id', gradeSectionId)
          .eq('is_active', true)
          .count();

      return response.count;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<StudentModel>> getStudentsWithPagination({
    required int offset,
    required int limit,
    String? gradeSectionId,
  }) async {
    try {
      var query = supabaseClient.from(_tableName).select('''
        *,
        grade_sections(
          section_name,
          grade_id,
          grades(grade_number)
        )
      ''').eq('is_active', true);

      if (gradeSectionId != null) {
        query = query.eq('grade_section_id', gradeSectionId);
      }

      final response = await query
          .order('roll_number', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => _mapJsonToStudent(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
