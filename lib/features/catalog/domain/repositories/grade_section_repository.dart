import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/grade_section.dart';

/// Repository for managing grade sections (A, B, C, etc. within each grade)
///
/// Handles all CRUD operations for grade_sections table
abstract class GradeSectionRepository {
  /// Get all sections for a tenant, optionally filtered by grade
  ///
  /// Returns list of GradeSection entities
  /// [tenantId] - the school/tenant ID
  /// [gradeId] - optional, filter by specific grade
  /// [activeOnly] - if true, only return is_active = true records
  Future<Either<Failure, List<GradeSection>>> getGradeSections({
    required String tenantId,
    String? gradeId,
    bool activeOnly = true,
  });

  /// Get a single section by ID
  Future<Either<Failure, GradeSection?>> getGradeSectionById(String id);

  /// Create a new grade section
  ///
  /// Example: Grade 5, Section A
  /// Returns the created section with ID assigned by database
  Future<Either<Failure, GradeSection>> createGradeSection(
    GradeSection section,
  );

  /// Update an existing grade section
  Future<Either<Failure, void>> updateGradeSection(GradeSection section);

  /// Soft delete a grade section (set is_active = false)
  ///
  /// Note: Uses soft delete to preserve historical data
  /// Papers and assignments won't be affected
  Future<Either<Failure, void>> deleteGradeSection(String id);

  /// Get all unique grades that have sections defined
  ///
  /// Used for UI dropdown: show only grades that have sections
  Future<Either<Failure, List<String>>> getGradesWithSections({
    required String tenantId,
    bool activeOnly = true,
  });
}
