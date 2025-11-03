import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../repositories/grade_section_repository.dart';

/// Use case: Delete (soft delete) a grade section
///
/// Called by: ManageGradeSectionsPage (when admin removes a section)
///
/// Note: Uses soft delete (is_active = false) to preserve historical data
/// Papers and assignments won't be affected
class DeleteGradeSectionUseCase {
  final GradeSectionRepository repository;

  DeleteGradeSectionUseCase({required this.repository});

  Future<Either<Failure, void>> call({required String sectionId}) async {
    return await repository.deleteGradeSection(sectionId);
  }
}
