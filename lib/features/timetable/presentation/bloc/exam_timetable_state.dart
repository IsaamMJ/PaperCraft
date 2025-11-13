import 'package:equatable/equatable.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../domain/entities/timetable_grade_entity.dart';

/// Base class for all exam timetable BLoC states
///
/// States represent the current state of the BLoC.
/// Each state is immutable and uses Equatable for equality comparison.
abstract class ExamTimetableState extends Equatable {
  const ExamTimetableState();

  @override
  List<Object?> get props => [];
}

/// Initial state - before any action is taken
class ExamTimetableInitial extends ExamTimetableState {
  const ExamTimetableInitial();
}

/// Loading state - request is in progress
class ExamTimetableLoading extends ExamTimetableState {
  final String message;

  const ExamTimetableLoading({this.message = 'Loading...'});

  @override
  List<Object?> get props => [message];
}

// ===== CALENDAR STATES =====

/// Success state: Calendars loaded
class ExamCalendarsLoaded extends ExamTimetableState {
  final List<ExamCalendarEntity> calendars;

  const ExamCalendarsLoaded({required this.calendars});

  @override
  List<Object?> get props => [calendars];
}

/// Success state: Calendar created
class ExamCalendarCreated extends ExamTimetableState {
  final ExamCalendarEntity calendar;

  const ExamCalendarCreated({required this.calendar});

  @override
  List<Object?> get props => [calendar];
}

/// Success state: Calendar updated
class ExamCalendarUpdated extends ExamTimetableState {
  final ExamCalendarEntity calendar;

  const ExamCalendarUpdated({required this.calendar});

  @override
  List<Object?> get props => [calendar];
}

/// Success state: Calendar deleted
class ExamCalendarDeleted extends ExamTimetableState {
  final String calendarId;

  const ExamCalendarDeleted({required this.calendarId});

  @override
  List<Object?> get props => [calendarId];
}

// ===== TIMETABLE STATES =====

/// Success state: Timetable loaded
class ExamTimetableLoaded extends ExamTimetableState {
  final ExamTimetableEntity timetable;

  const ExamTimetableLoaded({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Success state: Multiple timetables loaded
class ExamTimetablesLoaded extends ExamTimetableState {
  final List<ExamTimetableEntity> timetables;

  const ExamTimetablesLoaded({required this.timetables});

  @override
  List<Object?> get props => [timetables];
}

/// Success state: Timetable created
class ExamTimetableCreated extends ExamTimetableState {
  final ExamTimetableEntity timetable;

  const ExamTimetableCreated({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Success state: Timetable updated
class ExamTimetableUpdated extends ExamTimetableState {
  final ExamTimetableEntity timetable;

  const ExamTimetableUpdated({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Success state: Timetable published
class ExamTimetablePublished extends ExamTimetableState {
  final ExamTimetableEntity timetable;

  const ExamTimetablePublished({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Success state: Timetable archived
class ExamTimetableArchived extends ExamTimetableState {
  final ExamTimetableEntity timetable;

  const ExamTimetableArchived({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Success state: Timetable deleted
class ExamTimetableDeleted extends ExamTimetableState {
  final String timetableId;

  const ExamTimetableDeleted({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

// ===== ENTRY STATES =====

/// Success state: Entries loaded
class ExamTimetableEntriesLoaded extends ExamTimetableState {
  final List<ExamTimetableEntryEntity> entries;
  final ExamTimetableEntity? timetable; // Optional timetable reference

  const ExamTimetableEntriesLoaded({
    required this.entries,
    this.timetable,
  });

  @override
  List<Object?> get props => [entries, timetable];
}

/// Success state: Entry added
class ExamTimetableEntryAdded extends ExamTimetableState {
  final ExamTimetableEntryEntity entry;

  const ExamTimetableEntryAdded({required this.entry});

  @override
  List<Object?> get props => [entry];
}

/// Success state: Entry updated
class ExamTimetableEntryUpdated extends ExamTimetableState {
  final ExamTimetableEntryEntity entry;

  const ExamTimetableEntryUpdated({required this.entry});

  @override
  List<Object?> get props => [entry];
}

/// Success state: Entry deleted
class ExamTimetableEntryDeleted extends ExamTimetableState {
  final String entryId;

  const ExamTimetableEntryDeleted({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}

// ===== GRADES AND SECTIONS STATES =====

/// Success state: Timetable grades and sections loaded
///
/// Loaded from database respecting school-specific grade structure
/// Unlike hardcoded mock data, this reflects actual school configuration
class TimetableGradesAndSectionsLoaded extends ExamTimetableState {
  final TimetableGradesAndSectionsData gradesData;

  const TimetableGradesAndSectionsLoaded({required this.gradesData});

  @override
  List<Object?> get props => [gradesData];
}

/// Success state: Valid subjects for selected grades loaded
///
/// Contains map of grade-section combinations to their valid subjects
/// Used in Step 3 after user selects grades to populate Step 4 dropdowns
/// Format: {"1_A": ["EVS", "Math", "English"], "3_A": ["Science", "Math", "English"]}
class ValidSubjectsLoaded extends ExamTimetableState {
  final Map<String, List<String>> validSubjectsPerGradeSection;

  const ValidSubjectsLoaded({required this.validSubjectsPerGradeSection});

  @override
  List<Object?> get props => [validSubjectsPerGradeSection];
}

// ===== VALIDATION STATES =====

/// Success state: Validation completed
///
/// Contains list of validation errors (empty if valid)
class ExamTimetableValidated extends ExamTimetableState {
  final List<String> validationErrors;

  const ExamTimetableValidated({
    required this.validationErrors,
  });

  /// Whether the timetable passed validation
  bool get isValid => validationErrors.isEmpty;

  @override
  List<Object?> get props => [validationErrors];
}

/// Success state: Duplicate check completed
///
/// isDuplicate: true if duplicate entry exists, false otherwise
class DuplicateEntryChecked extends ExamTimetableState {
  final bool isDuplicate;

  const DuplicateEntryChecked({required this.isDuplicate});

  @override
  List<Object?> get props => [isDuplicate];
}

// ===== ERROR STATES =====

/// Error state: Operation failed
///
/// Contains error message and optional exception details
class ExamTimetableError extends ExamTimetableState {
  final String message;
  final String? code;
  final Exception? exception;

  const ExamTimetableError({
    required this.message,
    this.code,
    this.exception,
  });

  @override
  List<Object?> get props => [message, code, exception];
}

/// Error state: Validation failed
///
/// Contains list of validation error messages
class ExamTimetableValidationError extends ExamTimetableState {
  final List<String> errors;

  const ExamTimetableValidationError({required this.errors});

  @override
  List<Object?> get props => [errors];
}

/// Error state: Publication blocked
///
/// Contains reasons why timetable cannot be published
class ExamTimetablePublicationError extends ExamTimetableState {
  final List<String> validationErrors;

  const ExamTimetablePublicationError({required this.validationErrors});

  @override
  List<Object?> get props => [validationErrors];
}

/// Error state: Duplicate entry detected
///
/// Contains details about the duplicate entry
class DuplicateEntryError extends ExamTimetableState {
  final String gradeId;
  final String subjectId;
  final String section;
  final DateTime examDate;

  const DuplicateEntryError({
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.examDate,
  });

  @override
  List<Object?> get props => [gradeId, subjectId, section, examDate];
}

/// Error state: Permission denied
///
/// User doesn't have permission to perform this action
class ExamTimetablePermissionError extends ExamTimetableState {
  final String message;

  const ExamTimetablePermissionError({
    this.message = 'You do not have permission to perform this action',
  });

  @override
  List<Object?> get props => [message];
}

/// Error state: Network error
///
/// Network connection failed or unavailable
class ExamTimetableNetworkError extends ExamTimetableState {
  final String message;

  const ExamTimetableNetworkError({
    this.message = 'Network connection error. Please check your internet.',
  });

  @override
  List<Object?> get props => [message];
}

// ===== EXAM ENTRY STATES =====

/// Success state: Exam entries loaded
///
/// Contains all exam entries for a timetable
class ExamEntriesLoaded extends ExamTimetableState {
  final List<ExamTimetableEntryEntity> entries;

  const ExamEntriesLoaded({required this.entries});

  @override
  List<Object?> get props => [entries];
}

/// Success state: Exam entry added
///
/// New entry successfully created
class ExamEntryAdded extends ExamTimetableState {
  final ExamTimetableEntryEntity entry;

  const ExamEntryAdded({required this.entry});

  @override
  List<Object?> get props => [entry];
}

/// Success state: Exam entry deleted
///
/// Entry successfully removed from timetable
class ExamEntryDeleted extends ExamTimetableState {
  final String entryId;

  const ExamEntryDeleted({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}
