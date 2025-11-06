import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/teacher_subject_assignment_entity.dart';
import '../repositories/teacher_assignment_repository.dart';

/// Use case: Save or update a teacher assignment
///
/// Creates new assignment or updates existing via UPSERT
/// Validates assignment before saving
/// Used by: Teacher assignments management screen - inline editor
class SaveTeacherAssignmentUseCase {
  final TeacherAssignmentRepository repository;

  SaveTeacherAssignmentUseCase({required this.repository});

  Future<Either<Failure, void>> call(
    TeacherSubjectAssignmentEntity assignment,
  ) async {
    return await repository.saveAssignment(assignment);
  }
}
