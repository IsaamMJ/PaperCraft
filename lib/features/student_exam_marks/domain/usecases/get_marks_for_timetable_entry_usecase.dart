import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/student_exam_marks_entity.dart';
import '../repositories/student_exam_marks_repository.dart';

class GetMarksForTimetableEntryUsecase {
  final StudentExamMarksRepository _repository;

  GetMarksForTimetableEntryUsecase({required StudentExamMarksRepository repository})
      : _repository = repository;

  /// Get all marks for a specific exam timetable entry
  /// Includes student details (name, roll number, email)
  Future<Either<Failure, List<StudentExamMarksEntity>>> call({
    required String examTimetableEntryId,
  }) async {
    return await _repository.getMarksForTimetableEntry(examTimetableEntryId);
  }
}
