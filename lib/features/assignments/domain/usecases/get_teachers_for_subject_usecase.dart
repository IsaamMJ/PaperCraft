import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject.dart';
import '../repositories/teacher_subject_repository.dart';

/// Use case: Get all teachers assigned to a specific (grade, subject, section)
///
/// Called by: PublishExamTimetableUseCase
/// Purpose: When publishing timetable, find which teachers need papers for each entry
///
/// Example:
/// - Timetable entry: Grade 5-A Maths
/// - Query: Get all teachers assigned to (Grade 5, Maths, A)
/// - Result: [Anita Sharma, Priya Singh]
/// - Action: Create 2 papers (one for each teacher)
class GetTeachersForSubjectUseCase {
  final TeacherSubjectRepository repository;

  GetTeachersForSubjectUseCase({required this.repository});

  /// Get all teachers assigned to (grade, subject, section)
  ///
  /// Returns list of TeacherSubject entities
  /// Can extract teacherId from each entity if needed
  Future<Either<Failure, List<TeacherSubject>>> call({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
  }) async {
    return await repository.getTeachersFor(
      tenantId: tenantId,
      gradeId: gradeId,
      subjectId: subjectId,
      section: section,
      academicYear: academicYear,
      activeOnly: true,
    );
  }
}
