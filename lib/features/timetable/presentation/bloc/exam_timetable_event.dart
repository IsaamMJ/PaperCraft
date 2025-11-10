import 'package:equatable/equatable.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';

/// Base class for all exam timetable BLoC events
///
/// Events represent user actions or system events that trigger state changes.
/// Each event is immutable and uses Equatable for equality comparison.
abstract class ExamTimetableEvent extends Equatable {
  const ExamTimetableEvent();

  @override
  List<Object?> get props => [];
}

/// Event: Fetch all exam calendars
///
/// Triggered when user opens the calendar list
/// Results in ExamCalendarsLoaded or ExamCalendarsError state
class GetExamCalendarsEvent extends ExamTimetableEvent {
  final String tenantId;

  const GetExamCalendarsEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

/// Event: Fetch all exam timetables
///
/// Triggered when user opens timetable list/dashboard
/// Results in ExamTimetablesLoaded or ExamTimetablesError state
class GetExamTimetablesEvent extends ExamTimetableEvent {
  final String tenantId;
  final String? academicYear; // Optional filter

  const GetExamTimetablesEvent({
    required this.tenantId,
    this.academicYear,
  });

  @override
  List<Object?> get props => [tenantId, academicYear];
}

/// Event: Fetch a specific exam timetable by ID
///
/// Triggered when user opens a timetable detail page
/// Results in ExamTimetableLoaded or ExamTimetableError state
class GetExamTimetableByIdEvent extends ExamTimetableEvent {
  final String timetableId;

  const GetExamTimetableByIdEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Fetch all entries for a timetable
///
/// Triggered when user opens timetable entries list
/// Results in ExamTimetableEntriesLoaded or ExamTimetableEntriesError state
class GetExamTimetableEntriesEvent extends ExamTimetableEvent {
  final String timetableId;

  const GetExamTimetableEntriesEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Create a new exam timetable
///
/// Triggered when user submits timetable creation form
/// Results in ExamTimetableCreated or ExamTimetableError state
class CreateExamTimetableEvent extends ExamTimetableEvent {
  final ExamTimetableEntity timetable;

  const CreateExamTimetableEvent({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Event: Update an existing exam timetable
///
/// Triggered when user edits timetable details
/// Results in ExamTimetableUpdated or ExamTimetableError state
class UpdateExamTimetableEvent extends ExamTimetableEvent {
  final ExamTimetableEntity timetable;

  const UpdateExamTimetableEvent({required this.timetable});

  @override
  List<Object?> get props => [timetable];
}

/// Event: Publish an exam timetable
///
/// Triggered when user publishes a draft timetable
/// Results in ExamTimetablePublished or ExamTimetableError state
class PublishExamTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const PublishExamTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Archive an exam timetable
///
/// Triggered when user archives a published timetable
/// Results in ExamTimetableArchived or ExamTimetableError state
class ArchiveExamTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const ArchiveExamTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Delete an exam timetable
///
/// Triggered when user deletes a draft timetable
/// Results in ExamTimetableDeleted or ExamTimetableError state
class DeleteExamTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const DeleteExamTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Add an entry to a timetable
///
/// Triggered when user adds an exam entry
/// Results in ExamTimetableEntryAdded or ExamTimetableError state
class AddExamTimetableEntryEvent extends ExamTimetableEvent {
  final ExamTimetableEntryEntity entry;

  const AddExamTimetableEntryEvent({required this.entry});

  @override
  List<Object?> get props => [entry];
}

/// Event: Update an existing entry
///
/// Triggered when user edits an exam entry
/// Results in ExamTimetableEntryUpdated or ExamTimetableError state
class UpdateExamTimetableEntryEvent extends ExamTimetableEvent {
  final ExamTimetableEntryEntity entry;

  const UpdateExamTimetableEntryEvent({required this.entry});

  @override
  List<Object?> get props => [entry];
}

/// Event: Delete an exam entry
///
/// Triggered when user removes an exam entry
/// Results in ExamTimetableEntryDeleted or ExamTimetableError state
class DeleteExamTimetableEntryEvent extends ExamTimetableEvent {
  final String entryId;

  const DeleteExamTimetableEntryEvent({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}

/// Event: Validate a timetable
///
/// Triggered when user requests validation before publishing
/// Results in ExamTimetableValidated or ExamTimetableError state
class ValidateExamTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const ValidateExamTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Check for duplicate entry
///
/// Triggered when user adds a new entry to validate uniqueness
/// Results in DuplicateEntryChecked or ExamTimetableError state
class CheckDuplicateEntryEvent extends ExamTimetableEvent {
  final String timetableId;
  final String gradeId;
  final String subjectId;
  final DateTime examDate;
  final String section;

  const CheckDuplicateEntryEvent({
    required this.timetableId,
    required this.gradeId,
    required this.subjectId,
    required this.examDate,
    required this.section,
  });

  @override
  List<Object?> get props => [timetableId, gradeId, subjectId, examDate, section];
}

/// Event: Create an exam calendar
///
/// Triggered when admin creates a new exam calendar
/// Results in ExamCalendarCreated or ExamTimetableError state
class CreateExamCalendarEvent extends ExamTimetableEvent {
  final ExamCalendarEntity calendar;

  const CreateExamCalendarEvent({required this.calendar});

  @override
  List<Object?> get props => [calendar];
}

/// Event: Update an exam calendar
///
/// Triggered when admin updates calendar details
/// Results in ExamCalendarUpdated or ExamTimetableError state
class UpdateExamCalendarEvent extends ExamTimetableEvent {
  final ExamCalendarEntity calendar;

  const UpdateExamCalendarEvent({required this.calendar});

  @override
  List<Object?> get props => [calendar];
}

/// Event: Clear any error message
///
/// Triggered when user dismisses error snackbar
/// Results in state with error cleared
class ClearErrorEvent extends ExamTimetableEvent {
  const ClearErrorEvent();
}

/// Event: Reset BLoC to initial state
///
/// Triggered when user navigates away or clears filters
/// Results in ExamTimetableInitial state
class ResetExamTimetableEvent extends ExamTimetableEvent {
  const ResetExamTimetableEvent();
}

/// Event: Fetch grades and sections for timetable creation
///
/// Triggered when user opens timetable wizard step 3 (grades selection)
/// Results in TimetableGradesAndSectionsLoaded or ExamTimetableError state
/// Fetches actual school grade structure from database (not hardcoded)
class GetTimetableGradesAndSectionsEvent extends ExamTimetableEvent {
  final String tenantId;

  const GetTimetableGradesAndSectionsEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

// ===== EXAM ENTRY EVENTS =====

/// Event: Fetch all exam entries for a timetable
///
/// Triggered when user opens timetable to view/add entries
/// Results in ExamEntriesLoaded or ExamTimetableError state
class GetExamEntriesEvent extends ExamTimetableEvent {
  final String timetableId;

  const GetExamEntriesEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Event: Add a new exam entry
///
/// Triggered when user adds an exam entry via the form
/// Results in ExamEntryAdded or ExamTimetableError state
class AddExamEntryEvent extends ExamTimetableEvent {
  final String timetableId;
  final String gradeId;
  final String section;
  final String subjectId;
  final String subjectName;
  final DateTime examDate;
  final String startTime; // "09:00 AM"
  final int durationMinutes;
  final String? location;
  final String? notes;

  const AddExamEntryEvent({
    required this.timetableId,
    required this.gradeId,
    required this.section,
    required this.subjectId,
    required this.subjectName,
    required this.examDate,
    required this.startTime,
    required this.durationMinutes,
    this.location,
    this.notes,
  });

  @override
  List<Object?> get props => [
        timetableId,
        gradeId,
        section,
        subjectId,
        subjectName,
        examDate,
        startTime,
        durationMinutes,
        location,
        notes,
      ];
}

/// Event: Delete an exam entry
///
/// Triggered when user clicks delete on an entry
/// Results in ExamEntryDeleted or ExamTimetableError state
class DeleteExamEntryEvent extends ExamTimetableEvent {
  final String entryId;

  const DeleteExamEntryEvent({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}
