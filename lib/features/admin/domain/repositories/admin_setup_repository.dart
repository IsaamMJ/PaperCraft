import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';

/// Repository interface for admin setup operations
abstract class AdminSetupRepository {
  /// Get all available grades (1-12) for the tenant
  Future<Either<Failure, List<int>>> getAvailableGrades(String tenantId);

  /// Get subjects from catalog filtered by grade range
  /// Returns suggested subjects for a given grade
  Future<Either<Failure, List<String>>> getSubjectSuggestions(int gradeNumber);

  /// Get all subjects already added to the tenant
  Future<Either<Failure, List<String>>> getTenantSubjects(String tenantId);

  /// Create grades for the tenant
  Future<Either<Failure, void>> createGrades({
    required String tenantId,
    required List<int> gradeNumbers,
  });

  /// Create sections for a specific grade
  Future<Either<Failure, void>> createSections({
    required String tenantId,
    required int gradeNumber,
    required List<String> sections,
  });

  /// Create/link subjects to the tenant
  Future<Either<Failure, void>> createSubjectsForGrade({
    required String tenantId,
    required int gradeNumber,
    required List<String> subjectNames,
  });

  /// Update tenant details (name, address)
  Future<Either<Failure, void>> updateTenantDetails({
    required String tenantId,
    required String name,
    required String? address,
  });

  /// Mark tenant as initialized after setup
  Future<Either<Failure, void>> markTenantInitialized(String tenantId);

  /// Get complete setup data (for review step)
  Future<Either<Failure, Map<String, dynamic>>> getSetupSummary(String tenantId);
}
