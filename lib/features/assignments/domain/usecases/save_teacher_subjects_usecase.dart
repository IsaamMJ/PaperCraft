import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject.dart';
import '../repositories/teacher_subject_repository.dart';

/// Use case: Save all subject assignments for a teacher
///
/// Called by: TeacherProfileSetupPage during onboarding
///
/// This is a REPLACE operation:
/// 1. Deletes all existing assignments for this teacher+year
/// 2. Inserts new assignments from the list
///
/// Example:
/// Teacher selects: Grade 5-A Maths, Grade 5-B Maths, Grade 6-A Science
/// This saves 3 rows to teacher_subjects table
class SaveTeacherSubjectsUseCase {
  final TeacherSubjectRepository repository;

  SaveTeacherSubjectsUseCase({required this.repository});

  /// Save assignments for a teacher
  ///
  /// [tenantId] - school ID
  /// [teacherId] - teacher ID
  /// [academicYear] - e.g., "2024-2025"
  /// [assignments] - list of (grade, subject, section) tuples
  ///
  /// Returns Right(null) on success, Left(Failure) on error
  Future<Either<Failure, void>> call({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  }) async {
    // Validate that all assignments have the same tenant and teacher
    for (final assignment in assignments) {
      if (assignment.tenantId != tenantId) {
        return Left(
          ValidationFailure('All assignments must have same tenantId'),
        );
      }
      if (assignment.teacherId != teacherId) {
        return Left(
          ValidationFailure('All assignments must have same teacherId'),
        );
      }
      if (assignment.academicYear != academicYear) {
        return Left(
          ValidationFailure('All assignments must have same academicYear'),
        );
      }
    }

    return await repository.saveTeacherSubjects(
      tenantId: tenantId,
      teacherId: teacherId,
      academicYear: academicYear,
      assignments: assignments,
    );
  }
}
