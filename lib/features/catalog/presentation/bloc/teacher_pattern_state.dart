// features/catalog/presentation/bloc/teacher_pattern_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/teacher_pattern_entity.dart';

/// Base class for teacher pattern states
abstract class TeacherPatternState extends Equatable {
  const TeacherPatternState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class TeacherPatternInitial extends TeacherPatternState {}

/// Loading patterns
class TeacherPatternLoading extends TeacherPatternState {}

/// Patterns loaded successfully
class TeacherPatternLoaded extends TeacherPatternState {
  final List<TeacherPatternEntity> patterns;
  final TeacherPatternEntity? selectedPattern;

  const TeacherPatternLoaded({
    required this.patterns,
    this.selectedPattern,
  });

  @override
  List<Object?> get props => [patterns, selectedPattern];

  /// Copy with updated fields
  TeacherPatternLoaded copyWith({
    List<TeacherPatternEntity>? patterns,
    TeacherPatternEntity? selectedPattern,
    bool clearSelection = false,
  }) {
    return TeacherPatternLoaded(
      patterns: patterns ?? this.patterns,
      selectedPattern: clearSelection ? null : (selectedPattern ?? this.selectedPattern),
    );
  }
}

/// Pattern saved successfully (or existing incremented)
class TeacherPatternSaved extends TeacherPatternState {
  final TeacherPatternEntity pattern;
  final bool wasIncremented; // true if existing pattern was incremented

  const TeacherPatternSaved({
    required this.pattern,
    required this.wasIncremented,
  });

  @override
  List<Object?> get props => [pattern, wasIncremented];
}

/// Pattern deleted successfully
class TeacherPatternDeleted extends TeacherPatternState {
  final String patternId;

  const TeacherPatternDeleted(this.patternId);

  @override
  List<Object?> get props => [patternId];
}

/// Error occurred
class TeacherPatternError extends TeacherPatternState {
  final String message;

  const TeacherPatternError(this.message);

  @override
  List<Object?> get props => [message];
}
