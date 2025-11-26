import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/student_exam_marks_entity.dart';
import '../repositories/student_exam_marks_repository.dart';

class AutoCreateMarksForTimetableParams {
  final String examTimetableEntryId;
  final String gradeId;
  final String section;
  final String tenantId;

  AutoCreateMarksForTimetableParams({
    required this.examTimetableEntryId,
    required this.gradeId,
    required this.section,
    required this.tenantId,
  });
}

class AutoCreateMarksForTimetableUsecase {
  final StudentExamMarksRepository _repository;

  AutoCreateMarksForTimetableUsecase({required StudentExamMarksRepository repository})
      : _repository = repository;

  /// Auto-create marks records when a timetable entry is published
  /// Creates blank marks records for all active students in the grade/section
  /// Sets entered_by to the teacher assigned to that subject
  Future<Either<Failure, List<StudentExamMarksEntity>>> call({
    required AutoCreateMarksForTimetableParams params,
  }) async {
    return await _repository.autoCreateMarksForTimetableEntry(
      examTimetableEntryId: params.examTimetableEntryId,
      gradeId: params.gradeId,
      section: params.section,
      tenantId: params.tenantId,
    );
  }
}
