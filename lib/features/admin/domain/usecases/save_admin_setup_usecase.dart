import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/admin_setup_state.dart';
import '../repositories/admin_setup_repository.dart';

/// Use case to save the complete admin setup (grades, sections, subjects).
///
/// All operations are idempotent (upsert-based) so retrying a step is safe.
/// Each step is retried up to [_maxRetries] times on transient failures
/// before the whole save is reported as failed.
class SaveAdminSetupUseCase {
  final AdminSetupRepository repository;

  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(milliseconds: 800);

  SaveAdminSetupUseCase({required this.repository});

  /// Save the complete admin setup state.
  ///
  /// Steps executed in order (each retried up to [_maxRetries] on failure):
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
      // Step 1: Update tenant details if provided
      if (tenantName != null && tenantName.isNotEmpty) {
        final step1 = await _retryStep(
          stepName: 'tenant details',
          action: () => repository.updateTenantDetails(
            tenantId: setupState.tenantId,
            name: tenantName,
            address: tenantAddress,
          ),
        );
        if (step1.isLeft()) return step1;
      }

      // Step 2: Create all grades (idempotent via upsert — safe to retry)
      final gradeNumbers =
          setupState.selectedGrades.map((g) => g.gradeNumber).toList();

      final step2 = await _retryStep(
        stepName: 'grades',
        action: () => repository.createGrades(
          tenantId: setupState.tenantId,
          gradeNumbers: gradeNumbers,
        ),
      );
      if (step2.isLeft()) return step2;

      // Step 3: Create sections for each grade (idempotent via upsert)
      for (final grade in setupState.selectedGrades) {
        final sections = setupState.getSectionsForGrade(grade.gradeNumber);

        final step3 = await _retryStep(
          stepName: 'sections for grade ${grade.gradeNumber}',
          action: () => repository.createSections(
            tenantId: setupState.tenantId,
            gradeNumber: grade.gradeNumber,
            sections: sections,
          ),
        );
        if (step3.isLeft()) return step3;
      }

      // Step 4: Create subjects for each grade (collects from per-section data)
      for (final grade in setupState.selectedGrades) {
        final subjects = setupState.getAllSubjectsForGrade(grade.gradeNumber);
        if (subjects.isEmpty) continue;

        final step4 = await _retryStep(
          stepName: 'subjects for grade ${grade.gradeNumber}',
          action: () => repository.createSubjectsForGrade(
            tenantId: setupState.tenantId,
            gradeNumber: grade.gradeNumber,
            subjectNames: subjects,
          ),
        );
        if (step4.isLeft()) return step4;
      }

      // Step 5: Mark tenant as initialized
      final step5 = await _retryStep(
        stepName: 'finalize',
        action: () => repository.markTenantInitialized(setupState.tenantId),
      );
      if (step5.isLeft()) {
        return Left(ServerFailure(
          'Setup saved but failed to finalize. Please try again. '
          '${step5.fold((f) => f.message, (_) => '')}',
        ));
      }

      return step5;
    } catch (e) {
      return Left(ServerFailure('Failed to save setup: ${e.toString()}'));
    }
  }

  /// Retry a single step up to [_maxRetries] times.
  /// Returns the result of the last attempt.
  Future<Either<Failure, void>> _retryStep({
    required String stepName,
    required Future<Either<Failure, void>> Function() action,
  }) async {
    Either<Failure, void> lastResult = const Right(null);

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      lastResult = await action();
      if (lastResult.isRight()) return lastResult;

      // Don't delay after the final attempt
      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay);
      }
    }

    // All retries exhausted — wrap with step context
    return Left(ServerFailure(
      'Failed at $stepName after ${_maxRetries + 1} attempts: '
      '${lastResult.fold((f) => f.message, (_) => '')}',
    ));
  }
}
