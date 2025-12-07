import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/grade_section.dart';
import '../repositories/grade_section_repository.dart';

/// Use case: Load all grade sections for a tenant
///
/// Called by:
/// - ManageGradeSectionsPage (admin UI to manage sections)
/// - TeacherProfileSetupPage (to show available sections for selection)
///
/// Example usage:
/// ```dart
/// final result = await loadGradeSectionsUseCase(
///   tenantId: 'school-123',
///   gradeId: 'Grade 5', // optional, to filter by grade
/// );
///
/// result.fold(
///   (failure) => debugPrint('Error: ${failure.message}'),
///   (sections) => debugPrint('Found ${sections.length} sections'),
/// );
/// ```
class LoadGradeSectionsUseCase {
  final GradeSectionRepository repository;

  LoadGradeSectionsUseCase({required this.repository});

  /// Call the use case
  ///
  /// [tenantId] - the school/tenant ID
  /// [gradeId] - optional, filter by specific grade
  ///
  /// Returns Either<Failure, List<GradeSection>>
  /// - Left: Failure (error occurred)
  /// - Right: List of sections (may be empty if none exist)
  Future<Either<Failure, List<GradeSection>>> call({
    required String tenantId,
    String? gradeId,
  }) async {
    return await repository.getGradeSections(
      tenantId: tenantId,
      gradeId: gradeId,
      activeOnly: true,
    );
  }
}
