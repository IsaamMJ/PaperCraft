import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject_assignment_entity.dart';
import '../repositories/teacher_assignment_repository.dart';

/// Use case: Load all teacher assignments for a tenant
///
/// Can optionally filter by specific teacher and/or academic year
/// Used by: Teacher assignments management screen in settings
class LoadTeacherAssignmentsUseCase {
  final TeacherAssignmentRepository repository;

  LoadTeacherAssignmentsUseCase({required this.repository});

  Future<Either<Failure, List<TeacherSubjectAssignmentEntity>>> call({
    required String tenantId,
    String? teacherId,
    String academicYear = '2025-2026',
    bool activeOnly = true,
  }) async {
    return await repository.getTeacherAssignments(
      tenantId: tenantId,
      teacherId: teacherId,
      academicYear: academicYear,
      activeOnly: activeOnly,
    );
  }
}
