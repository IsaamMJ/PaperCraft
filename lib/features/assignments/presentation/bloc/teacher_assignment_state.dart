import 'package:equatable/equatable.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';

/// Base class for all TeacherAssignmentBloc states
abstract class TeacherAssignmentState extends Equatable {
  const TeacherAssignmentState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no data loaded yet
class TeacherAssignmentInitial extends TeacherAssignmentState {
  const TeacherAssignmentInitial();
}

/// Loading assignments from repository
class TeacherAssignmentsLoading extends TeacherAssignmentState {
  const TeacherAssignmentsLoading();
}

/// Successfully loaded assignments
class TeacherAssignmentsLoaded extends TeacherAssignmentState {
  final List<TeacherSubjectAssignmentEntity> assignments;
  final Map<String, int> stats; // "2:A" -> count

  const TeacherAssignmentsLoaded({
    required this.assignments,
    this.stats = const {},
  });

  @override
  List<Object?> get props => [assignments, stats];
}

/// Assignment operation (save/delete) succeeded
class AssignmentOperationSuccess extends TeacherAssignmentState {
  final String message;
  final bool shouldRefresh; // Whether to reload assignments after operation

  const AssignmentOperationSuccess({
    required this.message,
    this.shouldRefresh = true,
  });

  @override
  List<Object?> get props => [message, shouldRefresh];
}

/// Assignment was saved successfully
class AssignmentSaved extends AssignmentOperationSuccess {
  const AssignmentSaved()
      : super(
        message: 'Assignment saved successfully',
        shouldRefresh: true,
      );
}

/// Assignment was deleted successfully
class AssignmentDeleted extends AssignmentOperationSuccess {
  const AssignmentDeleted()
      : super(
        message: 'Assignment deleted successfully',
        shouldRefresh: true,
      );
}

/// Stats were refreshed successfully
class AssignmentStatsRefreshed extends TeacherAssignmentState {
  final Map<String, int> stats; // "2:A" -> count

  const AssignmentStatsRefreshed({required this.stats});

  @override
  List<Object?> get props => [stats];
}

/// Error occurred during operation
class TeacherAssignmentError extends TeacherAssignmentState {
  final String errorMessage;

  const TeacherAssignmentError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

/// Validation error (missing fields, invalid data)
class TeacherAssignmentValidationError extends TeacherAssignmentError {
  const TeacherAssignmentValidationError({required String errorMessage})
      : super(errorMessage: errorMessage);
}

/// All data has been cleared
class TeacherAssignmentCleared extends TeacherAssignmentState {
  const TeacherAssignmentCleared();
}
