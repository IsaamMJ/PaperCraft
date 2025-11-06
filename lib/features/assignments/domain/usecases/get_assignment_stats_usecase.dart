import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/teacher_assignment_repository.dart';

/// Use case: Get assignment statistics by grade+section
///
/// Returns map of "gradeNumber:section" → count of assignments
/// Used by: Teacher assignments dashboard to show summary stats
class GetAssignmentStatsUseCase {
  final TeacherAssignmentRepository repository;

  GetAssignmentStatsUseCase({required this.repository});

  Future<Either<Failure, Map<String, int>>> call({
    required String tenantId,
    String academicYear = '2025-2026',
  }) async {
    return await repository.getAssignmentStats(
      tenantId: tenantId,
      academicYear: academicYear,
    );
  }
}
