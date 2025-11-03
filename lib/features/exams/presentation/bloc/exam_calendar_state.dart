import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_calendar.dart';

/// States for ExamCalendarBloc
abstract class ExamCalendarState extends Equatable {
  const ExamCalendarState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ExamCalendarInitial extends ExamCalendarState {
  const ExamCalendarInitial();
}

/// Loading calendars
class ExamCalendarLoading extends ExamCalendarState {
  const ExamCalendarLoading();
}

/// Successfully loaded calendars
class ExamCalendarLoaded extends ExamCalendarState {
  final List<ExamCalendar> calendars;

  const ExamCalendarLoaded(this.calendars);

  @override
  List<Object?> get props => [calendars];
}

/// Empty list of calendars
class ExamCalendarEmpty extends ExamCalendarState {
  const ExamCalendarEmpty();
}

/// Error loading calendars
class ExamCalendarError extends ExamCalendarState {
  final String message;

  const ExamCalendarError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Creating calendar
class ExamCalendarCreating extends ExamCalendarState {
  const ExamCalendarCreating();
}

/// Successfully created calendar
class ExamCalendarCreated extends ExamCalendarState {
  final ExamCalendar calendar;

  const ExamCalendarCreated(this.calendar);

  @override
  List<Object?> get props => [calendar];
}

/// Error creating calendar
class ExamCalendarCreationError extends ExamCalendarState {
  final String message;

  const ExamCalendarCreationError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Deleting calendar
class ExamCalendarDeleting extends ExamCalendarState {
  final String calendarId;

  const ExamCalendarDeleting(this.calendarId);

  @override
  List<Object?> get props => [calendarId];
}

/// Successfully deleted calendar
class ExamCalendarDeleted extends ExamCalendarState {
  final String calendarId;

  const ExamCalendarDeleted(this.calendarId);

  @override
  List<Object?> get props => [calendarId];
}

/// Error deleting calendar
class ExamCalendarDeletionError extends ExamCalendarState {
  final String message;

  const ExamCalendarDeletionError(this.message);

  @override
  List<Object?> get props => [message];
}
