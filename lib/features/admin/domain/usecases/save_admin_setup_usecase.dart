import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/admin_setup_state.dart';
import '../repositories/admin_setup_repository.dart';

/// Use case to save the complete admin setup (grades, sections, subjects)
class SaveAdminSetupUseCase {
  final AdminSetupRepository repository;

  SaveAdminSetupUseCase({required this.repository});

  /// Save the complete admin setup state
  /// This performs multiple operations in sequence:
  /// 1. Update tenant details (name, address)
  /// 2. Create grades
  /// 3. Create sections for each grade
  /// 4. Create subjects for each grade
  /// 5. Mark tenant as initialized
  Future<Either<Failure, void>> call({
    required AdminSetupState setupState,
    String? tenantName,
    String? tenantAddress,
  }) async {
    try {
      // Step 0: Update tenant details if provided
      if (tenantName != null && tenantName.isNotEmpty) {
        final tenantResult = await repository.updateTenantDetails(
          tenantId: setupState.tenantId,
          name: tenantName,
          address: tenantAddress,
        );

        if (tenantResult.isLeft()) {
          return tenantResult;
        }
      }

      // Step 1: Create all grades
      final gradeNumbers = setupState.selectedGrades.map((g) => g.gradeNumber).toList();

      final gradesResult = await repository.createGrades(
        tenantId: setupState.tenantId,
        gradeNumbers: gradeNumbers,
      );

      if (gradesResult.isLeft()) {
        return gradesResult;
      }

      // Step 2: Create sections for each grade
      for (final grade in setupState.selectedGrades) {
        final sections = setupState.getSectionsForGrade(grade.gradeNumber);

        final sectionsResult = await repository.createSections(
          tenantId: setupState.tenantId,
          gradeNumber: grade.gradeNumber,
          sections: sections,
        );

        if (sectionsResult.isLeft()) {
          return sectionsResult;
        }
      }

      // Step 3: Create subjects for each grade
      for (final grade in setupState.selectedGrades) {
        final subjects = setupState.getSubjectsForGrade(grade.gradeNumber);

        final subjectsResult = await repository.createSubjectsForGrade(
          tenantId: setupState.tenantId,
          gradeNumber: grade.gradeNumber,
          subjectNames: subjects,
        );

        if (subjectsResult.isLeft()) {
          return subjectsResult;
        }
      }

      // Step 4: Mark tenant as initialized
      return repository.markTenantInitialized(setupState.tenantId);
    } catch (e) {
      return Left(ServerFailure('Failed to save setup: ${e.toString()}'));
    }
  }
}
