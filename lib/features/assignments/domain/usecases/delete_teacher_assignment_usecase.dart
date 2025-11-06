import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../repositories/teacher_assignment_repository.dart';

/// Use case: Delete (soft delete) a teacher assignment
///
/// Sets is_active = false instead of hard delete
/// Preserves record for audit trail and historical tracking
/// Used by: Teacher assignments management screen - delete action
class DeleteTeacherAssignmentUseCase {
  final TeacherAssignmentRepository repository;

  DeleteTeacherAssignmentUseCase({required this.repository});

  Future<Either<Failure, void>> call(String assignmentId) async {
    return await repository.deleteAssignment(assignmentId);
  }
}
