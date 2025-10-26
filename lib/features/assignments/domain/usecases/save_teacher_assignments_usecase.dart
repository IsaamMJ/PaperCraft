import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/assignment_repository.dart';

class SaveTeacherAssignmentsUseCase {
  final AssignmentRepository _repository;

  SaveTeacherAssignmentsUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String teacherId,
    required String academicYear,
    required List<String> gradeIds,
    required List<String> subjectIds,
  }) async {
    try {
      // Validate inputs
      if (gradeIds.isEmpty || subjectIds.isEmpty) {
        return Left(ValidationFailure('Please select at least one grade and subject'));
      }

      // Save all grade assignments
      for (final gradeId in gradeIds) {
        final result = await _repository.assignGradeToTeacher(
          teacherId: teacherId,
          gradeId: gradeId,
          academicYear: academicYear,
        );

        if (result.isLeft()) {
          return result;
        }
      }

      // Save all subject assignments
      for (final subjectId in subjectIds) {
        final result = await _repository.assignSubjectToTeacher(
          teacherId: teacherId,
          subjectId: subjectId,
          academicYear: academicYear,
        );

        if (result.isLeft()) {
          return result;
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to save assignments: ${e.toString()}'));
    }
  }
}
