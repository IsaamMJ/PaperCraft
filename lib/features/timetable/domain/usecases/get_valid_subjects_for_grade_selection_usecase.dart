import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/exam_timetable_repository.dart';

/// Use case to get valid subjects for selected grade-section combinations
///
/// Purpose: Ensures Step 4 of the wizard only shows subjects that are
/// actually configured in the academic structure for the selected grades.
///
/// Input: List of selected grade-section IDs from Step 3
/// Output: Map of (gradeNumber_section) -> list of valid subject names
///
/// Example:
///   Input: [gradeSection1 (Grade 1, A), gradeSection2 (Grade 1, B), gradeSection3 (Grade 3, A)]
///   Output: {
///     "1_A": ["EVS", "Math", "English"],
///     "1_B": ["EVS", "Math", "English"],
///     "3_A": ["Science", "Math", "English"]
///   }
class GetValidSubjectsForGradeSelectionUsecase {
  final ExamTimetableRepository repository;

  GetValidSubjectsForGradeSelectionUsecase({
    required this.repository,
  });

  Future<Either<Failure, Map<String, List<String>>>> call(
    GetValidSubjectsForGradeSelectionParams params,
  ) async {
    return await repository.getValidSubjectsForGradeSelection(
      tenantId: params.tenantId,
      selectedGradeSectionIds: params.selectedGradeSectionIds,
    );
  }
}

/// Parameters for GetValidSubjectsForGradeSelectionUsecase
class GetValidSubjectsForGradeSelectionParams {
  final String tenantId;
  final List<String> selectedGradeSectionIds;

  GetValidSubjectsForGradeSelectionParams({
    required this.tenantId,
    required this.selectedGradeSectionIds,
  });
}
