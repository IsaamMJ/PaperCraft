import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_timetable.dart';
import '../../domain/entities/exam_timetable_entry.dart';

/// States for ExamTimetableBloc
abstract class ExamTimetableState extends Equatable {
  const ExamTimetableState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ExamTimetableInitial extends ExamTimetableState {
  const ExamTimetableInitial();
}

/// Loading timetables
class ExamTimetableLoading extends ExamTimetableState {
  const ExamTimetableLoading();
}

/// Successfully loaded timetables
class ExamTimetableLoaded extends ExamTimetableState {
  final List<ExamTimetable> timetables;

  const ExamTimetableLoaded(this.timetables);

  @override
  List<Object?> get props => [timetables];
}

/// Empty list of timetables
class ExamTimetableEmpty extends ExamTimetableState {
  const ExamTimetableEmpty();
}

/// Error loading timetables
class ExamTimetableError extends ExamTimetableState {
  final String message;

  const ExamTimetableError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating timetable
class ExamTimetableCreating extends ExamTimetableState {
  const ExamTimetableCreating();
}

/// Successfully created timetable
class ExamTimetableCreated extends ExamTimetableState {
  final ExamTimetable timetable;

  const ExamTimetableCreated(this.timetable);

  @override
  List<Object?> get props => [timetable];
}

/// Error creating timetable
class ExamTimetableCreationError extends ExamTimetableState {
  final String message;

  const ExamTimetableCreationError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Loading timetable entries
class TimetableEntriesLoading extends ExamTimetableState {
  const TimetableEntriesLoading();
}

/// Successfully loaded entries
class TimetableEntriesLoaded extends ExamTimetableState {
  final List<ExamTimetableEntry> entries;

  const TimetableEntriesLoaded(this.entries);

  @override
  List<Object?> get props => [entries];
}

/// No entries for timetable
class TimetableEntriesEmpty extends ExamTimetableState {
  const TimetableEntriesEmpty();
}

/// Error loading entries
class TimetableEntriesError extends ExamTimetableState {
  final String message;

  const TimetableEntriesError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Adding entry to timetable
class AddingTimetableEntry extends ExamTimetableState {
  const AddingTimetableEntry();
}

/// Successfully added entry
class TimetableEntryAdded extends ExamTimetableState {
  final ExamTimetableEntry entry;

  const TimetableEntryAdded(this.entry);

  @override
  List<Object?> get props => [entry];
}

/// Error adding entry
class AddTimetableEntryError extends ExamTimetableState {
  final String message;

  const AddTimetableEntryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Validating timetable
class ValidatingTimetable extends ExamTimetableState {
  const ValidatingTimetable();
}

/// Timetable validation successful
class TimetableValidationSuccess extends ExamTimetableState {
  final List<String> warnings; // May have scheduling conflict warnings

  const TimetableValidationSuccess({this.warnings = const []});

  @override
  List<Object?> get props => [warnings];
}

/// Timetable validation failed
class TimetableValidationFailed extends ExamTimetableState {
  final List<String> errors;

  const TimetableValidationFailed(this.errors);

  @override
  List<Object?> get props => [errors];
}

/// Publishing timetable (with paper auto-creation)
class PublishingTimetable extends ExamTimetableState {
  const PublishingTimetable();
}

/// Successfully published timetable
class TimetablePublished extends ExamTimetableState {
  final ExamTimetable timetable;
  final int papersCreated;

  const TimetablePublished({
    required this.timetable,
    this.papersCreated = 0,
  });

  @override
  List<Object?> get props => [timetable, papersCreated];
}

/// Error publishing timetable
class PublishTimetableError extends ExamTimetableState {
  final String message;
  final List<String>? failedEntries; // Entries without teachers

  const PublishTimetableError(
    this.message, {
    this.failedEntries,
  });

  @override
  List<Object?> get props => [message, failedEntries];
}

/// Deleting timetable
class DeletingTimetable extends ExamTimetableState {
  final String timetableId;

  const DeletingTimetable(this.timetableId);

  @override
  List<Object?> get props => [timetableId];
}

/// Successfully deleted timetable
class TimetableDeleted extends ExamTimetableState {
  final String timetableId;

  const TimetableDeleted(this.timetableId);

  @override
  List<Object?> get props => [timetableId];
}

/// Error deleting timetable
class DeleteTimetableError extends ExamTimetableState {
  final String message;

  const DeleteTimetableError(this.message);

  @override
  List<Object?> get props => [message];
}
