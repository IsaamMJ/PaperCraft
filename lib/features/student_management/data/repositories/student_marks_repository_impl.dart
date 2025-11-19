import 'package:dartz/dartz.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/ilogger.dart';
import 'package:papercraft/core/domain/services/user_state_service.dart';
import 'package:papercraft/features/student_management/data/datasources/student_marks_remote_datasource.dart';
import 'package:papercraft/features/student_management/data/models/student_exam_marks_model.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_marks_repository.dart';

class StudentMarksRepositoryImpl implements StudentMarksRepository {
  final StudentMarksRemoteDataSource remoteDataSource;
  final ILogger logger;
  final UserStateService userStateService;

  StudentMarksRepositoryImpl({
    required this.remoteDataSource,
    required this.logger,
    required this.userStateService,
  });

  @override
  Future<Either<Failure, StudentExamMarksEntity>> addExamMarks({
    required String studentId,
    required String examTimetableEntryId,
    required double totalMarks,
    required StudentMarkStatus status,
    String? remarks,
  }) async {
    try {
      final tenantId = userStateService.currentTenantId;
      final userId = userStateService.currentUserId;

      final marks = StudentExamMarksModel(
        id: '',
        tenantId: tenantId,
        studentId: studentId,
        examTimetableEntryId: examTimetableEntryId,
        totalMarks: totalMarks,
        status: status,
        remarks: remarks,
        enteredBy: userId,
        isDraft: true,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await remoteDataSource.addExamMarks(marks);
      logger.info('Marks added for student: $studentId', category: 'MarksRepository');
      return Right(result);
    } on PostgrestException catch (e) {
      if (e.message.contains('unique_student_exam_marks')) {
        return Left(ValidationFailure('Marks already exist for this student-exam combination'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      logger.error('Error adding marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to add marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> getExamMarks(
    String examTimetableEntryId,
  ) async {
    try {
      final marks = await remoteDataSource.getExamMarks(examTimetableEntryId);
      return Right(marks.cast<StudentExamMarksEntity>());
    } catch (e) {
      logger.error('Error fetching exam marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, StudentExamMarksEntity>> getStudentExamMarks({
    required String studentId,
    required String examTimetableEntryId,
  }) async {
    try {
      final marks = await remoteDataSource.getStudentExamMarks(
        studentId: studentId,
        examTimetableEntryId: examTimetableEntryId,
      );
      if (marks == null) {
        return Left(NotFoundFailure('Marks not found'));
      }
      return Right(marks);
    } catch (e) {
      logger.error('Error fetching student marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> getDraftMarks(
    String examTimetableEntryId,
  ) async {
    try {
      final marks = await remoteDataSource.getDraftMarks(examTimetableEntryId);
      return Right(marks.cast<StudentExamMarksEntity>());
    } catch (e) {
      logger.error('Error fetching draft marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch draft marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, MarksSubmissionSummary>>> submitExamMarks(
    String examTimetableEntryId,
  ) async {
    try {
      await remoteDataSource.submitMarks(examTimetableEntryId);

      final stats = await remoteDataSource.getMarksStatistics(examTimetableEntryId);

      return Right(MarksSubmissionSummary(
        totalStudents: stats['total_count'] as int? ?? 0,
        markedPresent: stats['present_count'] as int? ?? 0,
        absent: (stats['absent_count'] as int? ?? 0) - (stats['not_appeared_count'] as int? ?? 0),
        medicalLeave: 0, // Can be calculated separately if needed
        notAppeared: stats['not_appeared_count'] as int? ?? 0,
        average: (stats['average'] as num?)?.toDouble() ?? 0.0,
        highestMarks: (stats['highest'] as num?)?.toDouble() ?? 0.0,
        lowestMarks: (stats['lowest'] as num?)?.toDouble() ?? 0.0,
      ));
    } catch (e) {
      logger.error('Error submitting marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to submit marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, StudentExamMarksEntity>> updateStudentMarks({
    required String studentId,
    required String examTimetableEntryId,
    required double totalMarks,
    required StudentMarkStatus status,
    String? remarks,
  }) async {
    try {
      final existing = await remoteDataSource.getStudentExamMarks(
        studentId: studentId,
        examTimetableEntryId: examTimetableEntryId,
      );

      if (existing == null || !existing.isDraft) {
        return Left(ValidationFailure('Cannot update submitted marks'));
      }

      final updated = existing.copyWith(
        totalMarks: totalMarks,
        status: status,
        remarks: remarks,
      );

      final result = await remoteDataSource.updateMarks(
        StudentExamMarksModel.fromEntity(updated),
      );
      return Right(result);
    } catch (e) {
      logger.error('Error updating marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to update marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> bulkUploadMarks({
    required String examTimetableEntryId,
    required List<Map<String, dynamic>> marksData,
  }) async {
    try {
      // TODO: Implement CSV validation and bulk upload logic
      return Left(ServerFailure('Not yet implemented'));
    } catch (e) {
      logger.error('Error bulk uploading marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to bulk upload marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMarks({
    required String studentId,
    required String examTimetableEntryId,
  }) async {
    try {
      await remoteDataSource.deleteMarks(
        studentId: studentId,
        examTimetableEntryId: examTimetableEntryId,
      );
      return const Right(null);
    } catch (e) {
      logger.error('Error deleting marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to delete marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, MarksSubmissionSummary>>> getMarksStatistics(
    String examTimetableEntryId,
  ) async {
    try {
      final stats = await remoteDataSource.getMarksStatistics(examTimetableEntryId);

      return Right(MarksSubmissionSummary(
        totalStudents: stats['total_count'] as int? ?? 0,
        markedPresent: stats['present_count'] as int? ?? 0,
        absent: (stats['absent_count'] as int? ?? 0),
        medicalLeave: 0,
        notAppeared: 0,
        average: (stats['average'] as num?)?.toDouble() ?? 0.0,
        highestMarks: (stats['highest'] as num?)?.toDouble() ?? 0.0,
        lowestMarks: (stats['lowest'] as num?)?.toDouble() ?? 0.0,
      ));
    } catch (e) {
      logger.error('Error fetching statistics: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch statistics: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> areMarksSubmitted(
    String examTimetableEntryId,
  ) async {
    try {
      final submitted = await remoteDataSource.areMarksSubmitted(examTimetableEntryId);
      return Right(submitted);
    } catch (e) {
      logger.error('Error checking submission status: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to check submission status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksByTeacher(String teacherId) async {
    try {
      final marks = await remoteDataSource.getMarksByTeacher(teacherId);
      return Right(marks.cast<StudentExamMarksEntity>());
    } catch (e) {
      logger.error('Error fetching teacher marks: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch marks: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StudentExamMarksEntity>>> getMarksByStatus({
    required String examTimetableEntryId,
    required StudentMarkStatus status,
  }) async {
    try {
      final marks = await remoteDataSource.getMarksByStatus(
        examTimetableEntryId: examTimetableEntryId,
        status: status.toString(),
      );
      return Right(marks.cast<StudentExamMarksEntity>());
    } catch (e) {
      logger.error('Error fetching marks by status: ${e.toString()}', category: 'MarksRepository');
      return Left(ServerFailure('Failed to fetch marks: ${e.toString()}'));
    }
  }
}
