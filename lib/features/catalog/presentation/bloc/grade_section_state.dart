import 'package:equatable/equatable.dart';
import '../../domain/entities/grade_section.dart';

/// States for GradeSectionBloc
abstract class GradeSectionState extends Equatable {
  const GradeSectionState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class GradeSectionInitial extends GradeSectionState {
  const GradeSectionInitial();
}

/// Loading sections
class GradeSectionLoading extends GradeSectionState {
  const GradeSectionLoading();
}

/// Successfully loaded sections
class GradeSectionLoaded extends GradeSectionState {
  final List<GradeSection> sections;

  const GradeSectionLoaded(this.sections);

  @override
  List<Object?> get props => [sections];
}

/// Empty list of sections
class GradeSectionEmpty extends GradeSectionState {
  const GradeSectionEmpty();
}

/// Error loading sections
class GradeSectionError extends GradeSectionState {
  final String message;

  const GradeSectionError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating a new section
class GradeSectionCreating extends GradeSectionState {
  const GradeSectionCreating();
}

/// Successfully created section
class GradeSectionCreated extends GradeSectionState {
  final GradeSection section;

  const GradeSectionCreated(this.section);

  @override
  List<Object?> get props => [section];
}

/// Error creating section
class GradeSectionCreationError extends GradeSectionState {
  final String message;

  const GradeSectionCreationError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Deleting a section
class GradeSectionDeleting extends GradeSectionState {
  final String sectionId;

  const GradeSectionDeleting(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

/// Successfully deleted section
class GradeSectionDeleted extends GradeSectionState {
  final String sectionId;

  const GradeSectionDeleted(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

/// Error deleting section
class GradeSectionDeletionError extends GradeSectionState {
  final String message;

  const GradeSectionDeletionError(this.message);

  @override
  List<Object?> get props => [message];
}
