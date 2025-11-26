import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/student_exam_marks_entity.dart';
import '../../domain/entities/student_mark_entry_dto.dart';
import '../../domain/repositories/student_exam_marks_repository.dart';
import '../datasources/student_exam_marks_cloud_data_source.dart';

class StudentExamMarksRepositoryImpl implements StudentExamMarksRepository {
  final StudentExamMarksCloudDataSource _cloudDataSource;

  StudentExamMarksRepositoryImpl(this._cloudDataSource);

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksForTimetableEntry(
    String examTimetableEntryId,
  ) async {
    try {
      final marks = await _cloudDataSource.getMarksForTimetableEntry(examTimetableEntryId);
      return Right(marks);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch marks: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, StudentExamMarksEntity>> getStudentMark(
    String studentId,
    String examTimetableEntryId,
  ) async {
    try {
      final mark = await _cloudDataSource.getStudentMark(studentId, examTimetableEntryId);
      if (mark == null) {
        return Left(
          ServerFailure('Student mark not found'),
        );
      }
      return Right(mark);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch student mark: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, MarksSubmissionResponse>> saveMarksAsDraft(
    BulkMarksEntryRequest request,
  ) async {
    try {
      final marksData = request.marks
          .map((mark) => {
            'student_id': mark.studentId,
            'exam_timetable_entry_id': request.examTimetableEntryId,
            'total_marks': mark.totalMarks,
            'status': mark.status,
            'remarks': mark.remarks,
            'entered_by': request.enteredBy,
            'is_draft': true,
          })
          .toList();

      await _cloudDataSource.saveMarksAsDraft(marksData);

      return Right(
        MarksSubmissionResponse(
          totalRecordsUpdated: marksData.length,
          successfulStudentIds: request.marks.map((m) => m.studentId).toList(),
          failedStudentIds: [],
          message: 'Marks saved as draft successfully',
        ),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to save marks: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, MarksSubmissionResponse>> submitMarks(
    BulkMarksEntryRequest request,
  ) async {
    try {
      final marksData = request.marks
          .map((mark) => {
            'student_id': mark.studentId,
            'exam_timetable_entry_id': request.examTimetableEntryId,
            'total_marks': mark.totalMarks,
            'status': mark.status,
            'remarks': mark.remarks,
            'entered_by': request.enteredBy,
            'is_draft': false,
          })
          .toList();

      await _cloudDataSource.submitMarks(marksData);

      return Right(
        MarksSubmissionResponse(
          totalRecordsUpdated: marksData.length,
          successfulStudentIds: request.marks.map((m) => m.studentId).toList(),
          failedStudentIds: [],
          message: 'Marks submitted successfully',
        ),
      );
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to submit marks: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> autoCreateMarksForTimetableEntry({
    required String examTimetableEntryId,
    required String gradeId,
    required String section,
    required String tenantId,
  }) async {
    try {
      final marks = await _cloudDataSource.autoCreateMarksForTimetableEntry(
        examTimetableEntryId: examTimetableEntryId,
        gradeId: gradeId,
        section: section,
        tenantId: tenantId,
      );
      return Right(marks);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to auto-create marks: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPapersWithMarksStatus(
    String teacherId,
    String tenantId,
  ) async {
    try {
      // This would fetch papers with their marks submission status
      // Implementation depends on the specific query structure
      // For now, returning empty to be implemented with exact DB query
      return const Right([]);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch papers with marks status: ${e.toString()}'),
      );
    }
  }
}
