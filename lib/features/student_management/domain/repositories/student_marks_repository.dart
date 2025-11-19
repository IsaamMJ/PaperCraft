import 'package:dartz/dartz.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';

/// Abstract repository for student exam marks operations
abstract class StudentMarksRepository {
  /// Add or update marks for a student in an exam
  Future<Either<Failure, StudentExamMarksEntity>> addExamMarks({
    required String studentId,
    required String examTimetableEntryId,
    required double totalMarks,
    required StudentMarkStatus status,
    String? remarks,
  });

  /// Get marks for all students in an exam
  Future<Either<Failure, List<StudentExamMarksEntity>>> getExamMarks(
    String examTimetableEntryId,
  );

  /// Get marks for a specific student in a specific exam
  Future<Either<Failure, StudentExamMarksEntity>> getStudentExamMarks({
    required String studentId,
    required String examTimetableEntryId,
  });

  /// Get draft marks for an exam (is_draft = true)
  Future<Either<Failure, List<StudentExamMarksEntity>>> getDraftMarks(
    String examTimetableEntryId,
  );

  /// Submit marks for an exam (set is_draft = false)
  /// This locks the marks from further editing
  Future<Either<Failure, MarksSubmissionSummary>>> submitExamMarks(
    String examTimetableEntryId,
  );

  /// Update a specific student's marks (only if in draft state)
  Future<Either<Failure, StudentExamMarksEntity>> updateStudentMarks({
    required String studentId,
    required String examTimetableEntryId,
    required double totalMarks,
    required StudentMarkStatus status,
    String? remarks,
  });

  /// Bulk upload marks from parsed CSV data
  /// Returns list of successfully added marks
  Future<Either<Failure, List<StudentExamMarksEntity>>> bulkUploadMarks({
    required String examTimetableEntryId,
    required List<Map<String, dynamic>> marksData,
  });

  /// Soft delete marks (set is_active = false)
  Future<Either<Failure, void>> deleteMarks({
    required String studentId,
    required String examTimetableEntryId,
  });

  /// Get marks statistics for an exam
  Future<Either<Failure, MarksSubmissionSummary>>> getMarksStatistics(
    String examTimetableEntryId,
  );

  /// Check if marks are already submitted for an exam
  Future<Either<Failure, bool>> areMarksSubmitted(
    String examTimetableEntryId,
  );

  /// Get all marks submitted by a specific teacher
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksByTeacher(
    String teacherId,
  );

  /// Get marks by status (absent, present, etc.)
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksByStatus({
    required String examTimetableEntryId,
    required StudentMarkStatus status,
  });
}
