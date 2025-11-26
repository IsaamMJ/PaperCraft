import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/student_exam_marks_entity.dart';
import '../entities/student_mark_entry_dto.dart';

abstract class StudentExamMarksRepository {
  /// Get all marks for a specific exam timetable entry
  /// Includes student details from joined students table
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksForTimetableEntry(
    String examTimetableEntryId,
  );

  /// Get a single student's mark record
  Future<Either<Failure, StudentExamMarksEntity>> getStudentMark(
    String studentId,
    String examTimetableEntryId,
  );

  /// Save marks as draft (without finalizing)
  /// Updates existing records or creates new ones
  Future<Either<Failure, MarksSubmissionResponse>> saveMarksAsDraft(
    BulkMarksEntryRequest request,
  );

  /// Submit marks (finalize)
  /// Sets is_draft=false, making them final
  /// Returns count of updated records
  Future<Either<Failure, MarksSubmissionResponse>> submitMarks(
    BulkMarksEntryRequest request,
  );

  /// Auto-create marks records for a new timetable entry
  /// Called when timetable is published
  Future<Either<Failure, List<StudentExamMarksEntity>>> autoCreateMarksForTimetableEntry({
    required String examTimetableEntryId,
    required String gradeId,
    required String section,
    required String tenantId,
  });

  /// Get marks with paper details for teacher's home page
  /// Shows papers grouped by exam_date
  Future<Either<Failure, List<Map<String, dynamic>>>> getPapersWithMarksStatus(
    String teacherId,
    String tenantId,
  );
}
