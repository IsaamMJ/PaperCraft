import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/exam_timetable.dart';

/// Events for ExamTimetableBloc
abstract class ExamTimetableEvent extends Equatable {
  const ExamTimetableEvent();

  @override
  List<Object?> get props => [];
}

/// Load exam timetables
class LoadExamTimetablesEvent extends ExamTimetableEvent {
  final String tenantId;
  final String? academicYear;
  final TimetableStatus? status; // Optional filter by status

  const LoadExamTimetablesEvent({
    required this.tenantId,
    this.academicYear,
    this.status,
  });

  @override
  List<Object?> get props => [tenantId, academicYear, status];
}

/// Create a new exam timetable
class CreateExamTimetableEvent extends ExamTimetableEvent {
  final String tenantId;
  final String createdBy;
  final String? examCalendarId;
  final String examName;
  final String examType;
  final int? examNumber; // For ad-hoc exams
  final String academicYear;

  const CreateExamTimetableEvent({
    required this.tenantId,
    required this.createdBy,
    this.examCalendarId,
    required this.examName,
    required this.examType,
    this.examNumber,
    required this.academicYear,
  });

  @override
  List<Object?> get props => [
    tenantId,
    createdBy,
    examCalendarId,
    examName,
    examType,
    examNumber,
    academicYear,
  ];
}

/// Add entry to timetable
class AddTimetableEntryEvent extends ExamTimetableEvent {
  final String tenantId;
  final String timetableId;
  final String gradeId;
  final String subjectId;
  final String section;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const AddTimetableEntryEvent({
    required this.tenantId,
    required this.timetableId,
    required this.gradeId,
    required this.subjectId,
    required this.section,
    required this.examDate,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [
    tenantId,
    timetableId,
    gradeId,
    subjectId,
    section,
    examDate,
    startTime,
    endTime,
  ];
}

/// Get timetable entries
class GetTimetableEntriesEvent extends ExamTimetableEvent {
  final String timetableId;

  const GetTimetableEntriesEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Delete timetable entry
class DeleteTimetableEntryEvent extends ExamTimetableEvent {
  final String entryId;

  const DeleteTimetableEntryEvent({required this.entryId});

  @override
  List<Object?> get props => [entryId];
}

/// Validate timetable for publishing
class ValidateTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const ValidateTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Publish timetable (triggers paper auto-creation)
class PublishTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const PublishTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Delete timetable
class DeleteTimetableEvent extends ExamTimetableEvent {
  final String timetableId;

  const DeleteTimetableEvent({required this.timetableId});

  @override
  List<Object?> get props => [timetableId];
}

/// Refresh timetables
class RefreshTimetablesEvent extends ExamTimetableEvent {
  final String tenantId;

  const RefreshTimetablesEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}
