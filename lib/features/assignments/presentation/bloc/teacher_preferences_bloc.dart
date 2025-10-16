// features/assignments/presentation/bloc/teacher_preferences_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../domain/repositories/assignment_repository.dart';

// =============== EVENTS ===============
abstract class TeacherPreferencesEvent extends Equatable {
  const TeacherPreferencesEvent();

  @override
  List<Object?> get props => [];
}

/// Load teacher preferences when user logs in
class LoadTeacherPreferences extends TeacherPreferencesEvent {
  final UserEntity user;

  const LoadTeacherPreferences(this.user);

  @override
  List<Object> get props => [user];
}

/// Clear preferences when user logs out
class ClearTeacherPreferences extends TeacherPreferencesEvent {
  const ClearTeacherPreferences();
}

// =============== STATES ===============
abstract class TeacherPreferencesState extends Equatable {
  const TeacherPreferencesState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no preferences loaded
class TeacherPreferencesInitial extends TeacherPreferencesState {
  const TeacherPreferencesInitial();
}

/// Loading teacher preferences
class TeacherPreferencesLoading extends TeacherPreferencesState {
  const TeacherPreferencesLoading();
}

/// Teacher preferences loaded successfully
class TeacherPreferencesLoaded extends TeacherPreferencesState {
  final String? defaultGradeFilter;
  final String? defaultSubjectFilter;
  final bool isTeacher;

  const TeacherPreferencesLoaded({
    this.defaultGradeFilter,
    this.defaultSubjectFilter,
    required this.isTeacher,
  });

  @override
  List<Object?> get props => [defaultGradeFilter, defaultSubjectFilter, isTeacher];

  bool get hasFilters => defaultGradeFilter != null || defaultSubjectFilter != null;
}

/// Error loading teacher preferences (non-critical - app continues)
class TeacherPreferencesError extends TeacherPreferencesState {
  final String message;

  const TeacherPreferencesError(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class TeacherPreferencesBloc extends Bloc<TeacherPreferencesEvent, TeacherPreferencesState> {
  final AssignmentRepository _assignmentRepository;

  TeacherPreferencesBloc({
    required AssignmentRepository assignmentRepository,
  })  : _assignmentRepository = assignmentRepository,
        super(const TeacherPreferencesInitial()) {
    on<LoadTeacherPreferences>(_onLoadTeacherPreferences);
    on<ClearTeacherPreferences>(_onClearTeacherPreferences);
  }

  Future<void> _onLoadTeacherPreferences(
    LoadTeacherPreferences event,
    Emitter<TeacherPreferencesState> emit,
  ) async {
    // Only load for teachers
    if (event.user.role != UserRole.teacher) {
      emit(const TeacherPreferencesLoaded(
        defaultGradeFilter: null,
        defaultSubjectFilter: null,
        isTeacher: false,
      ));
      return;
    }

    emit(const TeacherPreferencesLoading());

    try {
      final currentYear = DateTime.now().year.toString();

      // Fetch teacher assignments in parallel
      final results = await Future.wait([
        _assignmentRepository.getTeacherAssignedGrades(event.user.id, currentYear),
        _assignmentRepository.getTeacherAssignedSubjects(event.user.id, currentYear),
      ]);

      String? gradeFilter;
      String? subjectFilter;

      // Process grades result
      final gradesResult = results[0];
      gradesResult.fold(
        (failure) => null,
        (grades) {
          final gradesList = grades as List;
          if (gradesList.isNotEmpty) {
            gradeFilter = gradesList.first.gradeNumber.toString();
          }
        },
      );

      // Process subjects result
      final subjectsResult = results[1];
      subjectsResult.fold(
        (failure) => null,
        (subjects) {
          final subjectsList = subjects as List;
          if (subjectsList.isNotEmpty) {
            subjectFilter = subjectsList.first.id;
          }
        },
      );

      emit(TeacherPreferencesLoaded(
        defaultGradeFilter: gradeFilter,
        defaultSubjectFilter: subjectFilter,
        isTeacher: true,
      ));
    } catch (e) {
      // Non-critical error - emit loaded state without filters
      emit(const TeacherPreferencesLoaded(
        defaultGradeFilter: null,
        defaultSubjectFilter: null,
        isTeacher: true,
      ));
    }
  }

  Future<void> _onClearTeacherPreferences(
    ClearTeacherPreferences event,
    Emitter<TeacherPreferencesState> emit,
  ) async {
    emit(const TeacherPreferencesInitial());
  }
}
