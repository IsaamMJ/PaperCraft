import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject.dart';
import '../repositories/teacher_subject_repository.dart';

/// Use case: Load all subjects assigned to a teacher
///
/// Called by: Teacher's profile page to show their current assignments
class LoadTeacherSubjectsUseCase {
  final TeacherSubjectRepository repository;

  LoadTeacherSubjectsUseCase({required this.repository});

  Future<Either<Failure, List<TeacherSubject>>> call({
    required String tenantId,
    required String teacherId,
    required String academicYear,
  }) async {
    return await repository.getTeacherSubjects(
      tenantId: tenantId,
      teacherId: teacherId,
      academicYear: academicYear,
      activeOnly: true,
    );
  }
}
