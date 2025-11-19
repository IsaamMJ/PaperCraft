import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_marks_repository.dart';

/// Add marks for a student in an exam
class AddExamMarksUseCase {
  final StudentMarksRepository repository;

  AddExamMarksUseCase(this.repository);

  Future<Either<Failure, StudentExamMarksEntity>> call(
    AddExamMarksParams params,
  ) async {
    return await repository.addExamMarks(
      studentId: params.studentId,
      examTimetableEntryId: params.examTimetableEntryId,
      totalMarks: params.totalMarks,
      status: params.status,
      remarks: params.remarks,
    );
  }
}

class AddExamMarksParams extends Equatable {
  final String studentId;
  final String examTimetableEntryId;
  final double totalMarks;
  final StudentMarkStatus status;
  final String? remarks;

  const AddExamMarksParams({
    required this.studentId,
    required this.examTimetableEntryId,
    required this.totalMarks,
    required this.status,
    this.remarks,
  });

  @override
  List<Object?> get props => [
        studentId,
        examTimetableEntryId,
        totalMarks,
        status,
        remarks,
      ];
}

/// Get marks for an exam
class GetExamMarksUseCase {
  final StudentMarksRepository repository;

  GetExamMarksUseCase(this.repository);

  Future<Either<Failure, List<StudentExamMarksEntity>>> call(
    String examTimetableEntryId,
  ) async {
    return await repository.getExamMarks(examTimetableEntryId);
  }
}

/// Submit marks for an exam (locks editing)
class SubmitMarksUseCase {
  final StudentMarksRepository repository;

  SubmitMarksUseCase(this.repository);

  Future<Either<Failure, MarksSubmissionSummary>>> call(
    String examTimetableEntryId,
  ) async {
    return await repository.submitExamMarks(examTimetableEntryId);
  }
}

/// Update a student's marks (only if in draft)
class UpdateStudentMarksUseCase {
  final StudentMarksRepository repository;

  UpdateStudentMarksUseCase(this.repository);

  Future<Either<Failure, StudentExamMarksEntity>> call(
    UpdateMarksParams params,
  ) async {
    return await repository.updateStudentMarks(
      studentId: params.studentId,
      examTimetableEntryId: params.examTimetableEntryId,
      totalMarks: params.totalMarks,
      status: params.status,
      remarks: params.remarks,
    );
  }
}

class UpdateMarksParams extends Equatable {
  final String studentId;
  final String examTimetableEntryId;
  final double totalMarks;
  final StudentMarkStatus status;
  final String? remarks;

  const UpdateMarksParams({
    required this.studentId,
    required this.examTimetableEntryId,
    required this.totalMarks,
    required this.status,
    this.remarks,
  });

  @override
  List<Object?> get props => [
        studentId,
        examTimetableEntryId,
        totalMarks,
        status,
        remarks,
      ];
}

/// Bulk upload marks from CSV
class BulkUploadMarksUseCase {
  final StudentMarksRepository repository;

  BulkUploadMarksUseCase(this.repository);

  Future<Either<Failure, List<StudentExamMarksEntity>>> call(
    BulkUploadMarksParams params,
  ) async {
    return await repository.bulkUploadMarks(
      examTimetableEntryId: params.examTimetableEntryId,
      marksData: params.marksData,
    );
  }
}

class BulkUploadMarksParams extends Equatable {
  final String examTimetableEntryId;
  final List<Map<String, dynamic>> marksData;

  const BulkUploadMarksParams({
    required this.examTimetableEntryId,
    required this.marksData,
  });

  @override
  List<Object?> get props => [examTimetableEntryId, marksData];
}

/// Get marks statistics for an exam
class GetMarksStatisticsUseCase {
  final StudentMarksRepository repository;

  GetMarksStatisticsUseCase(this.repository);

  Future<Either<Failure, MarksSubmissionSummary>>> call(
    String examTimetableEntryId,
  ) async {
    return await repository.getMarksStatistics(examTimetableEntryId);
  }
}
