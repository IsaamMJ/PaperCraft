// features/catalog/presentation/bloc/teacher_pattern_event.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/paper_section_entity.dart';
import '../../domain/entities/teacher_pattern_entity.dart';

/// Base class for teacher pattern events
abstract class TeacherPatternEvent extends Equatable {
  const TeacherPatternEvent();

  @override
  List<Object?> get props => [];
}

/// Load patterns for a teacher and subject
class LoadTeacherPatterns extends TeacherPatternEvent {
  final String teacherId;
  final String subjectId;

  const LoadTeacherPatterns({
    required this.teacherId,
    required this.subjectId,
  });

  @override
  List<Object?> get props => [teacherId, subjectId];
}

/// Load frequently used patterns
class LoadFrequentPatterns extends TeacherPatternEvent {
  final String teacherId;
  final String subjectId;

  const LoadFrequentPatterns({
    required this.teacherId,
    required this.subjectId,
  });

  @override
  List<Object?> get props => [teacherId, subjectId];
}

/// Save a new pattern (or increment existing if duplicate)
class SaveTeacherPattern extends TeacherPatternEvent {
  final TeacherPatternEntity pattern;

  const SaveTeacherPattern(this.pattern);

  @override
  List<Object?> get props => [pattern];
}

/// Update an existing pattern
class UpdateTeacherPattern extends TeacherPatternEvent {
  final TeacherPatternEntity pattern;

  const UpdateTeacherPattern(this.pattern);

  @override
  List<Object?> get props => [pattern];
}

/// Delete a pattern
class DeleteTeacherPattern extends TeacherPatternEvent {
  final String patternId;

  const DeleteTeacherPattern(this.patternId);

  @override
  List<Object?> get props => [patternId];
}

/// Select a pattern to use
class SelectPattern extends TeacherPatternEvent {
  final TeacherPatternEntity? pattern;

  const SelectPattern(this.pattern);

  @override
  List<Object?> get props => [pattern];
}
