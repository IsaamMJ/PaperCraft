import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/exam_calendar_repository.dart';
import '../../domain/usecases/load_exam_calendars_usecase.dart';
import '../../domain/usecases/create_exam_calendar_usecase.dart';
import '../../domain/usecases/delete_exam_calendar_usecase.dart';
import 'exam_calendar_event.dart';
import 'exam_calendar_state.dart';

/// BLoC for managing exam calendars
class ExamCalendarBloc extends Bloc<ExamCalendarEvent, ExamCalendarState> {
  final LoadExamCalendarsUseCase loadExamCalendarsUseCase;
  final CreateExamCalendarUseCase createExamCalendarUseCase;
  final DeleteExamCalendarUseCase deleteExamCalendarUseCase;
  final ExamCalendarRepository repository;

  ExamCalendarBloc({
    required this.loadExamCalendarsUseCase,
    required this.createExamCalendarUseCase,
    required this.deleteExamCalendarUseCase,
    required this.repository,
  }) : super(const ExamCalendarInitial()) {
    on<LoadExamCalendarsEvent>(_onLoadExamCalendars);

    on<CreateExamCalendarEvent>(_onCreateExamCalendar);

    on<DeleteExamCalendarEvent>(_onDeleteExamCalendar);

    on<RefreshExamCalendarsEvent>(_onRefreshExamCalendars);
  }

  /// Load exam calendars
  Future<void> _onLoadExamCalendars(
    LoadExamCalendarsEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {

    emit(const ExamCalendarLoading());

    final result = await loadExamCalendarsUseCase(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    );

    result.fold(
      (failure) {
        emit(ExamCalendarError(failure.message));
      },
      (calendars) {
        if (calendars.isEmpty) {
          emit(const ExamCalendarEmpty());
        } else {
          emit(ExamCalendarLoaded(calendars));
        }
      },
    );
  }

  /// Create a new exam calendar
  Future<void> _onCreateExamCalendar(
    CreateExamCalendarEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {

    emit(const ExamCalendarCreating());

    final result = await createExamCalendarUseCase(
      tenantId: event.tenantId,
      examName: event.examName,
      examType: event.examType,
      monthNumber: event.monthNumber,
      plannedStartDate: event.plannedStartDate,
      plannedEndDate: event.plannedEndDate,
      paperSubmissionDeadline: event.paperSubmissionDeadline,
      displayOrder: event.displayOrder,
      marksConfig: event.marksConfig,
      selectedGradeNumbers: event.selectedGradeNumbers,
      coreMaxMarks: event.coreMaxMarks,
      auxiliaryMaxMarks: event.auxiliaryMaxMarks,
    );

    result.fold(
      (failure) {
        emit(ExamCalendarCreationError(failure.message));
      },
      (calendar) {
        emit(ExamCalendarCreated(calendar));
        // Auto-reload calendars after creation
        add(LoadExamCalendarsEvent(
          tenantId: event.tenantId,
          academicYear: calendar.toJson()['academic_year'] ?? '',
        ));
      },
    );
  }

  /// Delete an exam calendar
  Future<void> _onDeleteExamCalendar(
    DeleteExamCalendarEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {
    emit(ExamCalendarDeleting(event.calendarId));

    final result = await deleteExamCalendarUseCase(calendarId: event.calendarId);

    result.fold(
      (failure) {
        emit(ExamCalendarDeletionError(failure.message));
      },
      (_) {
        emit(ExamCalendarDeleted(event.calendarId));
      },
    );
  }

  /// Refresh exam calendars
  Future<void> _onRefreshExamCalendars(
    RefreshExamCalendarsEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {
    add(LoadExamCalendarsEvent(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    ));
  }
}
