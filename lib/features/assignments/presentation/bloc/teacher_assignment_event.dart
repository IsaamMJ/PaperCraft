import 'package:equatable/equatable.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';

/// Base class for all TeacherAssignmentBloc events
abstract class TeacherAssignmentEvent extends Equatable {
  const TeacherAssignmentEvent();

  @override
  List<Object?> get props => [];
}

/// Load all teacher assignments with optional filtering
class LoadTeacherAssignmentsEvent extends TeacherAssignmentEvent {
  final String tenantId;
  final String? teacherId; // Optional: filter by specific teacher
  final String academicYear;
  final bool activeOnly;

  const LoadTeacherAssignmentsEvent({
    required this.tenantId,
    this.teacherId,
    this.academicYear = '2025-2026',
    this.activeOnly = true,
  });

  @override
  List<Object?> get props => [tenantId, teacherId, academicYear, activeOnly];
}

/// Save or update a single teacher assignment
class SaveTeacherAssignmentEvent extends TeacherAssignmentEvent {
  final TeacherSubjectAssignmentEntity assignment;

  const SaveTeacherAssignmentEvent({required this.assignment});

  @override
  List<Object?> get props => [assignment];
}

/// Delete (soft delete) a teacher assignment
class DeleteTeacherAssignmentEvent extends TeacherAssignmentEvent {
  final String assignmentId;

  const DeleteTeacherAssignmentEvent({required this.assignmentId});

  @override
  List<Object?> get props => [assignmentId];
}

/// Refresh assignment statistics (counts by grade+section)
class RefreshAssignmentStatsEvent extends TeacherAssignmentEvent {
  final String tenantId;
  final String academicYear;

  const RefreshAssignmentStatsEvent({
    required this.tenantId,
    this.academicYear = '2025-2026',
  });

  @override
  List<Object?> get props => [tenantId, academicYear];
}

/// Clear all state and reset BLoC
class ClearTeacherAssignmentsEvent extends TeacherAssignmentEvent {
  const ClearTeacherAssignmentsEvent();
}
