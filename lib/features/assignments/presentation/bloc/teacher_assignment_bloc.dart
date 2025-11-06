import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';
import '../../domain/usecases/delete_teacher_assignment_usecase.dart';
import '../../domain/usecases/get_assignment_stats_usecase.dart';
import '../../domain/usecases/load_teacher_assignments_usecase.dart';
import '../../domain/usecases/save_teacher_assignment_usecase.dart';
import 'teacher_assignment_event.dart';
import 'teacher_assignment_state.dart';

/// BLoC for managing teacher assignments
///
/// Handles loading, saving, deleting, and managing statistics for teacher assignments
/// Used by: Settings screen, Teacher assignments management page
class TeacherAssignmentBloc extends Bloc<TeacherAssignmentEvent, TeacherAssignmentState> {
  final LoadTeacherAssignmentsUseCase loadTeacherAssignmentsUseCase;
  final SaveTeacherAssignmentUseCase saveTeacherAssignmentUseCase;
  final DeleteTeacherAssignmentUseCase deleteTeacherAssignmentUseCase;
  final GetAssignmentStatsUseCase getAssignmentStatsUseCase;

  TeacherAssignmentBloc({
    required this.loadTeacherAssignmentsUseCase,
    required this.saveTeacherAssignmentUseCase,
    required this.deleteTeacherAssignmentUseCase,
    required this.getAssignmentStatsUseCase,
  }) : super(const TeacherAssignmentInitial()) {
    on<LoadTeacherAssignmentsEvent>(_onLoadTeacherAssignments);
    on<SaveTeacherAssignmentEvent>(_onSaveTeacherAssignment);
    on<DeleteTeacherAssignmentEvent>(_onDeleteTeacherAssignment);
    on<RefreshAssignmentStatsEvent>(_onRefreshAssignmentStats);
    on<ClearTeacherAssignmentsEvent>(_onClearTeacherAssignments);
  }

  /// Load all teacher assignments
  Future<void> _onLoadTeacherAssignments(
    LoadTeacherAssignmentsEvent event,
    Emitter<TeacherAssignmentState> emit,
  ) async {
    emit(const TeacherAssignmentsLoading());

    final result = await loadTeacherAssignmentsUseCase(
      tenantId: event.tenantId,
      teacherId: event.teacherId,
      academicYear: event.academicYear,
      activeOnly: event.activeOnly,
    );

    if (result.isLeft()) {
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) {
        emit(TeacherAssignmentError(errorMessage: failure.message));
      }
      return;
    }

    final assignments = result.fold<List<TeacherSubjectAssignmentEntity>>(
      (_) => [],
      (a) => a,
    );

    // Also load stats for the current view
    final statsResult = await getAssignmentStatsUseCase(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    );

    statsResult.fold(
      (failure) {
        // Emit loaded state without stats if stats loading fails
        emit(TeacherAssignmentsLoaded(assignments: assignments));
      },
      (stats) {
        emit(TeacherAssignmentsLoaded(
          assignments: assignments,
          stats: stats,
        ));
      },
    );
  }

  /// Save or update a teacher assignment
  Future<void> _onSaveTeacherAssignment(
    SaveTeacherAssignmentEvent event,
    Emitter<TeacherAssignmentState> emit,
  ) async {

    final result = await saveTeacherAssignmentUseCase(event.assignment);


    result.fold(
      (failure) {
        // Emit appropriate error state based on failure type
        if (failure.message.contains('grade') ||
            failure.message.contains('section') ||
            failure.message.contains('subject')) {
          emit(
            TeacherAssignmentValidationError(
              errorMessage: failure.message,
            ),
          );
        } else {
          emit(TeacherAssignmentError(errorMessage: failure.message));
        }
      },
      (_) {
        emit(const AssignmentSaved());
      },
    );
  }

  /// Delete a teacher assignment
  Future<void> _onDeleteTeacherAssignment(
    DeleteTeacherAssignmentEvent event,
    Emitter<TeacherAssignmentState> emit,
  ) async {
    final result = await deleteTeacherAssignmentUseCase(event.assignmentId);

    result.fold(
      (failure) => emit(
        TeacherAssignmentError(errorMessage: failure.message),
      ),
      (_) {
        emit(const AssignmentDeleted());
      },
    );
  }

  /// Refresh assignment statistics
  Future<void> _onRefreshAssignmentStats(
    RefreshAssignmentStatsEvent event,
    Emitter<TeacherAssignmentState> emit,
  ) async {
    final result = await getAssignmentStatsUseCase(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    );

    result.fold(
      (failure) => emit(
        TeacherAssignmentError(errorMessage: failure.message),
      ),
      (stats) {
        emit(AssignmentStatsRefreshed(stats: stats));
      },
    );
  }

  /// Clear all state
  Future<void> _onClearTeacherAssignments(
    ClearTeacherAssignmentsEvent event,
    Emitter<TeacherAssignmentState> emit,
  ) async {
    emit(const TeacherAssignmentCleared());
  }
}