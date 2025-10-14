// features/catalog/presentation/bloc/teacher_pattern_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/delete_teacher_pattern_usecase.dart';
import '../../domain/usecases/get_teacher_patterns_usecase.dart';
import '../../domain/usecases/save_teacher_pattern_usecase.dart';
import 'teacher_pattern_event.dart';
import 'teacher_pattern_state.dart';

/// BLoC for managing teacher patterns
class TeacherPatternBloc extends Bloc<TeacherPatternEvent, TeacherPatternState> {
  final GetTeacherPatternsUseCase getPatterns;
  final SaveTeacherPatternUseCase savePattern;
  final DeleteTeacherPatternUseCase deletePattern;

  TeacherPatternBloc({
    required this.getPatterns,
    required this.savePattern,
    required this.deletePattern,
  }) : super(TeacherPatternInitial()) {
    on<LoadTeacherPatterns>(_onLoadPatterns);
    on<LoadFrequentPatterns>(_onLoadFrequentPatterns);
    on<SaveTeacherPattern>(_onSavePattern);
    on<UpdateTeacherPattern>(_onUpdatePattern);
    on<DeleteTeacherPattern>(_onDeletePattern);
    on<SelectPattern>(_onSelectPattern);
  }

  /// Load all patterns for teacher/subject
  Future<void> _onLoadPatterns(
    LoadTeacherPatterns event,
    Emitter<TeacherPatternState> emit,
  ) async {
    emit(TeacherPatternLoading());

    final result = await getPatterns(
      teacherId: event.teacherId,
      subjectId: event.subjectId,
    );

    result.fold(
      (failure) => emit(TeacherPatternError(failure.message)),
      (patterns) => emit(TeacherPatternLoaded(patterns: patterns)),
    );
  }

  /// Load frequently used patterns
  Future<void> _onLoadFrequentPatterns(
    LoadFrequentPatterns event,
    Emitter<TeacherPatternState> emit,
  ) async {
    emit(TeacherPatternLoading());

    final result = await getPatterns(
      teacherId: event.teacherId,
      subjectId: event.subjectId,
    );

    result.fold(
      (failure) => emit(TeacherPatternError(failure.message)),
      (patterns) => emit(TeacherPatternLoaded(patterns: patterns)),
    );
  }

  /// Save pattern (or increment existing if duplicate)
  Future<void> _onSavePattern(
    SaveTeacherPattern event,
    Emitter<TeacherPatternState> emit,
  ) async {
    final result = await savePattern(pattern: event.pattern);

    result.fold(
      (failure) => emit(TeacherPatternError(failure.message)),
      (savedPattern) {
        // Check if this was an increment or new creation
        final wasIncremented = savedPattern.useCount > 0;
        emit(TeacherPatternSaved(
          pattern: savedPattern,
          wasIncremented: wasIncremented,
        ));
      },
    );
  }

  /// Update existing pattern
  Future<void> _onUpdatePattern(
    UpdateTeacherPattern event,
    Emitter<TeacherPatternState> emit,
  ) async {
    // For update, use the save pattern with the updated entity
    final result = await savePattern(pattern: event.pattern);

    result.fold(
      (failure) => emit(TeacherPatternError(failure.message)),
      (updatedPattern) => emit(TeacherPatternSaved(
        pattern: updatedPattern,
        wasIncremented: false,
      )),
    );
  }

  /// Delete pattern
  Future<void> _onDeletePattern(
    DeleteTeacherPattern event,
    Emitter<TeacherPatternState> emit,
  ) async {
    final result = await deletePattern(patternId: event.patternId);

    result.fold(
      (failure) => emit(TeacherPatternError(failure.message)),
      (_) => emit(TeacherPatternDeleted(event.patternId)),
    );
  }

  /// Select pattern to use
  Future<void> _onSelectPattern(
    SelectPattern event,
    Emitter<TeacherPatternState> emit,
  ) async {
    if (state is TeacherPatternLoaded) {
      final currentState = state as TeacherPatternLoaded;
      emit(currentState.copyWith(
        selectedPattern: event.pattern,
        clearSelection: event.pattern == null,
      ));
    }
  }
}
