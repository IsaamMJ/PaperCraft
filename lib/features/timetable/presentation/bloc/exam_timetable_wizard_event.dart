import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';

/// Base event for exam timetable wizard
abstract class ExamTimetableWizardEvent extends Equatable {
  const ExamTimetableWizardEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the wizard with tenant context
class InitializeWizardEvent extends ExamTimetableWizardEvent {
  final String tenantId;
  final String userId;
  final String academicYear;

  const InitializeWizardEvent({
    required this.tenantId,
    required this.userId,
    required this.academicYear,
  });

  @override
  List<Object?> get props => [tenantId, userId, academicYear];
}

/// Step 1: Select an exam calendar
class SelectExamCalendarEvent extends ExamTimetableWizardEvent {
  final ExamCalendarEntity calendar;

  const SelectExamCalendarEvent({
    required this.calendar,
  });

  @override
  List<Object?> get props => [calendar];
}

/// Step 2: Update user's selected grade sections (local UI state)
class UpdateUserGradeSelectionEvent extends ExamTimetableWizardEvent {
  final List<String> selectedGradeSectionIds;

  const UpdateUserGradeSelectionEvent({
    required this.selectedGradeSectionIds,
  });

  @override
  List<Object?> get props => [selectedGradeSectionIds];
}

/// Step 2 → Step 3: Select grade sections and proceed to next step
class SelectGradesEvent extends ExamTimetableWizardEvent {
  final String examCalendarId;
  final List<String> gradeSectionIds;

  const SelectGradesEvent({
    required this.examCalendarId,
    required this.gradeSectionIds,
  });

  @override
  List<Object?> get props => [examCalendarId, gradeSectionIds];
}

/// Step 3: Assign a subject to an exam date for a specific grade
class AssignSubjectDateEvent extends ExamTimetableWizardEvent {
  final String subjectId;
  final String gradeId;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const AssignSubjectDateEvent({
    required this.subjectId,
    required this.gradeId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [subjectId, gradeId, examDate, startTime, endTime];
}

/// Remove a subject assignment (before submission)
class RemoveSubjectAssignmentEvent extends ExamTimetableWizardEvent {
  final String subjectId;

  const RemoveSubjectAssignmentEvent({
    required this.subjectId,
  });

  @override
  List<Object?> get props => [subjectId];
}

/// Update a subject assignment (change date/time)
class UpdateSubjectAssignmentEvent extends ExamTimetableWizardEvent {
  final String subjectId;
  final String gradeId;
  final DateTime newExamDate;
  final TimeOfDay newStartTime;
  final TimeOfDay newEndTime;

  const UpdateSubjectAssignmentEvent({
    required this.subjectId,
    required this.gradeId,
    required this.newExamDate,
    required this.newStartTime,
    required this.newEndTime,
  });

  @override
  List<Object?> get props => [
    subjectId,
    gradeId,
    newExamDate,
    newStartTime,
    newEndTime,
  ];
}

/// Step 2 → Step 3: Go to next step (teacher assignment)
/// Validates that at least ONE subject has a date assigned
class GoToNextStepEvent extends ExamTimetableWizardEvent {
  const GoToNextStepEvent();

  @override
  List<Object?> get props => [];
}

/// Step 3: Load teacher assignments for all scheduled subjects
///
/// Triggered: When entering Step 3 (after scheduling subjects)
/// Purpose: Fetch which teachers are assigned to each subject+grade+section
/// Result: Emits WizardStep3State with teacher data populated
class LoadTeacherAssignmentsEvent extends ExamTimetableWizardEvent {
  final String tenantId;
  final String academicYear;

  const LoadTeacherAssignmentsEvent({
    required this.tenantId,
    required this.academicYear,
  });

  @override
  List<Object?> get props => [tenantId, academicYear];
}

/// Step 3: Submit the wizard and create timetable
class SubmitWizardEvent extends ExamTimetableWizardEvent {
  const SubmitWizardEvent();

  @override
  List<Object?> get props => [];
}

/// Go back to previous step
class GoBackEvent extends ExamTimetableWizardEvent {
  const GoBackEvent();

  @override
  List<Object?> get props => [];
}

/// Reset the entire wizard
class ResetWizardEvent extends ExamTimetableWizardEvent {
  const ResetWizardEvent();

  @override
  List<Object?> get props => [];
}

/// Batch assign multiple subjects to the same date/time for all their grades
/// Use case: Assign Math, Science, English all to June 1, 9:00-11:00 AM
class BatchAssignSubjectsEvent extends ExamTimetableWizardEvent {
  final List<String> subjectIds;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const BatchAssignSubjectsEvent({
    required this.subjectIds,
    required this.examDate,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [subjectIds, examDate, startTime, endTime];
}