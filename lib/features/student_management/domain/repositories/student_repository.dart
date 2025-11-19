import 'package:dartz/dartz.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';

/// Abstract repository for student management operations
abstract class StudentRepository {
  /// Add a single student to a grade section
  Future<Either<Failure, StudentEntity>> addStudent({
    required String gradeSectionId,
    required String rollNumber,
    required String fullName,
    String? email,
    String? phone,
  });

  /// Get all active students for a specific grade section
  Future<Either<Failure, List<StudentEntity>>> getStudentsByGradeSection(
    String gradeSectionId,
  );

  /// Get a single student by ID
  Future<Either<Failure, StudentEntity>> getStudentById(String studentId);

  /// Get all active students for the current academic year
  Future<Either<Failure, List<StudentEntity>>> getActiveStudents();

  /// Update student information
  Future<Either<Failure, StudentEntity>> updateStudent(StudentEntity student);

  /// Soft delete a student (set is_active to false)
  Future<Either<Failure, void>> deleteStudent(String studentId);

  /// Bulk upload students from parsed CSV data
  /// Returns list of successfully added students
  Future<Either<Failure, List<StudentEntity>>> bulkUploadStudents({
    required String gradeSectionId,
    required List<Map<String, String>> studentData,
  });

  /// Check if a student with roll number already exists in a grade section
  Future<Either<Failure, bool>> studentExists({
    required String gradeSectionId,
    required String rollNumber,
  });

  /// Get students count for a grade section
  Future<Either<Failure, int>> getStudentsCountByGradeSection(
    String gradeSectionId,
  );

  /// Get all students with pagination
  Future<Either<Failure, List<StudentEntity>>> getStudentsWithPagination({
    required int page,
    required int pageSize,
    String? gradeSectionId,
  });
}
