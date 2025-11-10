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
    print('[ExamCalendarBloc] CONSTRUCTOR CALLED - Initializing handlers');
    on<LoadExamCalendarsEvent>(_onLoadExamCalendars);
    print('[ExamCalendarBloc] Registered LoadExamCalendarsEvent handler');

    on<CreateExamCalendarEvent>(_onCreateExamCalendar);
    print('[ExamCalendarBloc] Registered CreateExamCalendarEvent handler');

    on<DeleteExamCalendarEvent>(_onDeleteExamCalendar);
    print('[ExamCalendarBloc] Registered DeleteExamCalendarEvent handler');

    on<RefreshExamCalendarsEvent>(_onRefreshExamCalendars);
    print('[ExamCalendarBloc] Registered RefreshExamCalendarsEvent handler');
  }

  /// Load exam calendars
  Future<void> _onLoadExamCalendars(
    LoadExamCalendarsEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {
    print('[ExamCalendarBloc] Loading exam calendars...');
    print('[ExamCalendarBloc] TenantId: ${event.tenantId}');
    print('[ExamCalendarBloc] AcademicYear: ${event.academicYear}');

    emit(const ExamCalendarLoading());

    final result = await loadExamCalendarsUseCase(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    );

    result.fold(
      (failure) {
        print('[ExamCalendarBloc] ERROR loading calendars: ${failure.message}');
        emit(ExamCalendarError(failure.message));
      },
      (calendars) {
        print('[ExamCalendarBloc] Successfully loaded ${calendars.length} calendars');
        if (calendars.isEmpty) {
          print('[ExamCalendarBloc] No calendars found, emitting empty state');
          emit(const ExamCalendarEmpty());
        } else {
          print('[ExamCalendarBloc] Emitting loaded state with calendars');
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
    print('[ExamCalendarBloc] Creating exam calendar...');
    print('[ExamCalendarBloc] Exam Name: ${event.examName}');
    print('[ExamCalendarBloc] Exam Type: ${event.examType}');
    print('[ExamCalendarBloc] Start Date: ${event.plannedStartDate}');
    print('[ExamCalendarBloc] End Date: ${event.plannedEndDate}');

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
    );

    result.fold(
      (failure) {
        print('[ExamCalendarBloc] ERROR creating calendar: ${failure.message}');
        emit(ExamCalendarCreationError(failure.message));
      },
      (calendar) {
        print('[ExamCalendarBloc] Calendar created successfully with ID: ${calendar.id}');
        emit(ExamCalendarCreated(calendar));
        // Auto-reload calendars after creation
        print('[ExamCalendarBloc] Auto-reloading calendars after creation');
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
    print('[ExamCalendarBloc] Deleting exam calendar with ID: ${event.calendarId}');
    emit(ExamCalendarDeleting(event.calendarId));

    final result = await deleteExamCalendarUseCase(calendarId: event.calendarId);

    result.fold(
      (failure) {
        print('[ExamCalendarBloc] ERROR deleting calendar: ${failure.message}');
        emit(ExamCalendarDeletionError(failure.message));
      },
      (_) {
        print('[ExamCalendarBloc] Calendar deleted successfully with ID: ${event.calendarId}');
        emit(ExamCalendarDeleted(event.calendarId));
      },
    );
  }

  /// Refresh exam calendars
  Future<void> _onRefreshExamCalendars(
    RefreshExamCalendarsEvent event,
    Emitter<ExamCalendarState> emit,
  ) async {
    print('[ExamCalendarBloc] Refreshing exam calendars...');
    print('[ExamCalendarBloc] TenantId: ${event.tenantId}');
    print('[ExamCalendarBloc] AcademicYear: ${event.academicYear}');
    add(LoadExamCalendarsEvent(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
    ));
  }
}
