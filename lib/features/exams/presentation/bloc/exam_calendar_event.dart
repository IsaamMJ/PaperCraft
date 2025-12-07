import 'package:equatable/equatable.dart';

/// Events for ExamCalendarBloc
abstract class ExamCalendarEvent extends Equatable {
  const ExamCalendarEvent();

  @override
  List<Object?> get props => [];
}

/// Load exam calendars
class LoadExamCalendarsEvent extends ExamCalendarEvent {
  final String tenantId;
  final String academicYear;

  const LoadExamCalendarsEvent({
    required this.tenantId,
    required this.academicYear,
  });

  @override
  List<Object?> get props => [tenantId, academicYear];
}

/// Create a new exam calendar entry
class CreateExamCalendarEvent extends ExamCalendarEvent {
  final String tenantId;
  final String examName;
  final String examType;
  final int monthNumber;
  final DateTime plannedStartDate;
  final DateTime plannedEndDate;
  final DateTime? paperSubmissionDeadline;
  final int displayOrder;
  final Map<String, dynamic>? marksConfig;
  final List<int>? selectedGradeNumbers;
  final int? coreMaxMarks;
  final int? auxiliaryMaxMarks;

  const CreateExamCalendarEvent({
    required this.tenantId,
    required this.examName,
    required this.examType,
    required this.monthNumber,
    required this.plannedStartDate,
    required this.plannedEndDate,
    this.paperSubmissionDeadline,
    required this.displayOrder,
    this.marksConfig,
    this.selectedGradeNumbers,
    this.coreMaxMarks,
    this.auxiliaryMaxMarks,
  });

  @override
  List<Object?> get props => [
    tenantId,
    examName,
    examType,
    monthNumber,
    plannedStartDate,
    plannedEndDate,
    paperSubmissionDeadline,
    displayOrder,
    marksConfig,
    selectedGradeNumbers,
    coreMaxMarks,
    auxiliaryMaxMarks,
  ];
}

/// Delete exam calendar
class DeleteExamCalendarEvent extends ExamCalendarEvent {
  final String calendarId;

  const DeleteExamCalendarEvent({required this.calendarId});

  @override
  List<Object?> get props => [calendarId];
}

/// Refresh exam calendars
class RefreshExamCalendarsEvent extends ExamCalendarEvent {
  final String tenantId;
  final String academicYear;

  const RefreshExamCalendarsEvent({
    required this.tenantId,
    required this.academicYear,
  });

  @override
  List<Object?> get props => [tenantId, academicYear];
}
