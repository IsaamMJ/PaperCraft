import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/exam_timetable.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case: Load all timetables for a tenant
///
/// Called by: ExamTimetableListPage (admin views list of timetables)
class LoadExamTimetablesUseCase {
  final ExamTimetableRepository repository;

  LoadExamTimetablesUseCase({required this.repository});

  Future<Either<Failure, List<ExamTimetable>>> call({
    required String tenantId,
    String? academicYear,
    TimetableStatus? status,
  }) async {
    return await repository.getTimetablesForTenant(
      tenantId: tenantId,
      academicYear: academicYear,
      status: status,
      activeOnly: true,
    );
  }
}
