// features/assignments/domain/repositories/assignment_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';

abstract class AssignmentRepository {
  // Get assigned grades for a teacher
  Future<Either<Failure, List<GradeEntity>>> getTeacherAssignedGrades(
      String teacherId,
      String academicYear,
      );

  // Get assigned subjects for a teacher
  Future<Either<Failure, List<SubjectEntity>>> getTeacherAssignedSubjects(
      String teacherId,
      String academicYear,
      );

  // Assign grade to teacher
  Future<Either<Failure, void>> assignGradeToTeacher({
    required String teacherId,
    required String gradeId,
    required String academicYear,
  });

  // Assign subject to teacher
  Future<Either<Failure, void>> assignSubjectToTeacher({
    required String teacherId,
    required String subjectId,
    required String academicYear,
  });

  // Remove grade assignment
  Future<Either<Failure, void>> removeGradeAssignment({
    required String teacherId,
    required String gradeId,
    required String academicYear,
  });

  // Remove subject assignment
  Future<Either<Failure, void>> removeSubjectAssignment({
    required String teacherId,
    required String subjectId,
    required String academicYear,
  });
}