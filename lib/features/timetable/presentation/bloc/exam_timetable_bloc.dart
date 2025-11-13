import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../domain/usecases/add_exam_timetable_entry_usecase.dart';
import '../../domain/usecases/create_exam_timetable_usecase.dart';
import '../../domain/usecases/get_exam_calendars_usecase.dart';
import '../../domain/usecases/get_exam_timetables_usecase.dart';
import '../../domain/usecases/get_timetable_grades_and_sections_usecase.dart';
import '../../domain/usecases/get_valid_subjects_for_grade_selection_usecase.dart';
import '../../domain/usecases/publish_exam_timetable_usecase.dart';
import '../../domain/usecases/validate_exam_timetable_usecase.dart';
import '../../domain/repositories/exam_timetable_repository.dart';
import 'exam_timetable_event.dart';
import 'exam_timetable_state.dart';

/// ExamTimetableBloc - Business Logic Component
///
/// Manages all exam timetable operations and state management.
/// Acts as a bridge between presentation layer (UI) and domain layer (business logic).
///
/// Responsibilities:
/// - Handle user interactions (events)
/// - Execute use cases
/// - Manage state transitions
/// - Error handling and user feedback
///
/// Usage in UI:
/// ```dart
/// BlocListener<ExamTimetableBloc, ExamTimetableState>(
///   listener: (context, state) {
///     if (state is ExamTimetableError) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text(state.message)),
///       );
///     }
///   },
/// );
/// ```
class ExamTimetableBloc extends Bloc<ExamTimetableEvent, ExamTimetableState> {
  final GetExamCalendarsUsecase _getExamCalendarsUsecase;
  final GetExamTimetablesUsecase _getExamTimetablesUsecase;
  final CreateExamTimetableUsecase _createExamTimetableUsecase;
  final PublishExamTimetableUsecase _publishExamTimetableUsecase;
  final AddExamTimetableEntryUsecase _addExamTimetableEntryUsecase;
  final ValidateExamTimetableUsecase _validateExamTimetableUsecase;
  final GetTimetableGradesAndSectionsUsecase _getTimetableGradesAndSectionsUsecase;
  final GetValidSubjectsForGradeSelectionUsecase _getValidSubjectsUsecase;
  final ExamTimetableRepository _repository;

  ExamTimetableBloc({
    required GetExamCalendarsUsecase getExamCalendarsUsecase,
    required GetExamTimetablesUsecase getExamTimetablesUsecase,
    required CreateExamTimetableUsecase createExamTimetableUsecase,
    required PublishExamTimetableUsecase publishExamTimetableUsecase,
    required AddExamTimetableEntryUsecase addExamTimetableEntryUsecase,
    required ValidateExamTimetableUsecase validateExamTimetableUsecase,
    required GetTimetableGradesAndSectionsUsecase getTimetableGradesAndSectionsUsecase,
    required GetValidSubjectsForGradeSelectionUsecase getValidSubjectsUsecase,
    required ExamTimetableRepository repository,
  })  : _getExamCalendarsUsecase = getExamCalendarsUsecase,
        _getExamTimetablesUsecase = getExamTimetablesUsecase,
        _createExamTimetableUsecase = createExamTimetableUsecase,
        _publishExamTimetableUsecase = publishExamTimetableUsecase,
        _addExamTimetableEntryUsecase = addExamTimetableEntryUsecase,
        _validateExamTimetableUsecase = validateExamTimetableUsecase,
        _getTimetableGradesAndSectionsUsecase = getTimetableGradesAndSectionsUsecase,
        _getValidSubjectsUsecase = getValidSubjectsUsecase,
        _repository = repository,
        super(const ExamTimetableInitial()) {
    // Register event handlers
    on<GetExamCalendarsEvent>(_onGetExamCalendars);
    on<GetExamTimetablesEvent>(_onGetExamTimetables);
    on<GetExamTimetableByIdEvent>(_onGetExamTimetableById);
    on<GetExamTimetableEntriesEvent>(_onGetExamTimetableEntries);
    on<CreateExamTimetableEvent>(_onCreateExamTimetable);
    on<UpdateExamTimetableEvent>(_onUpdateExamTimetable);
    on<PublishExamTimetableEvent>(_onPublishExamTimetable);
    on<ArchiveExamTimetableEvent>(_onArchiveExamTimetable);
    on<DeleteExamTimetableEvent>(_onDeleteExamTimetable);
    on<AddExamTimetableEntryEvent>(_onAddExamTimetableEntry);
    on<UpdateExamTimetableEntryEvent>(_onUpdateExamTimetableEntry);
    on<DeleteExamTimetableEntryEvent>(_onDeleteExamTimetableEntry);
    on<ValidateExamTimetableEvent>(_onValidateExamTimetable);
    on<CheckDuplicateEntryEvent>(_onCheckDuplicateEntry);
    on<CreateExamCalendarEvent>(_onCreateExamCalendar);
    on<UpdateExamCalendarEvent>(_onUpdateExamCalendar);
    on<GetTimetableGradesAndSectionsEvent>(_onGetTimetableGradesAndSections);
    on<LoadValidSubjectsEvent>(_onLoadValidSubjects);
    on<GetExamEntriesEvent>(_onGetExamEntries);
    on<AddExamEntryEvent>(_onAddExamEntry);
    on<DeleteExamEntryEvent>(_onDeleteExamEntry);
    on<ClearErrorEvent>(_onClearError);
    on<ResetExamTimetableEvent>(_onResetState);
  }

  // ===== EVENT HANDLERS =====

  /// Handler: GetExamCalendarsEvent
  Future<void> _onGetExamCalendars(
    GetExamCalendarsEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetExamCalendars: tenantId=${event.tenantId}');
    emit(const ExamTimetableLoading(message: 'Loading calendars...'));

    final result = await _getExamCalendarsUsecase(
      params: GetExamCalendarsParams(tenantId: event.tenantId),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] GetExamCalendars ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (calendars) {
        print('[ExamTimetableBloc] GetExamCalendars SUCCESS: loaded ${calendars.length} calendars');
        emit(ExamCalendarsLoaded(calendars: calendars));
      },
    );
  }

  /// Handler: GetExamTimetablesEvent
  Future<void> _onGetExamTimetables(
    GetExamTimetablesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetExamTimetables: tenantId=${event.tenantId}, academicYear=${event.academicYear}');
    emit(const ExamTimetableLoading(message: 'Loading timetables...'));

    final result = await _getExamTimetablesUsecase(
      params: GetExamTimetablesParams(
        tenantId: event.tenantId,
        academicYear: event.academicYear,
      ),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] GetExamTimetables ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (timetables) {
        print('[ExamTimetableBloc] GetExamTimetables SUCCESS: loaded ${timetables.length} timetables');
        emit(ExamTimetablesLoaded(timetables: timetables));
      },
    );
  }

  /// Handler: GetExamTimetableByIdEvent
  Future<void> _onGetExamTimetableById(
    GetExamTimetableByIdEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetExamTimetableById: timetableId=${event.timetableId}');
    emit(const ExamTimetableLoading(message: 'Loading timetable...'));

    final result = await _repository.getExamTimetableById(event.timetableId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] GetExamTimetableById ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (timetable) {
        print('[ExamTimetableBloc] GetExamTimetableById SUCCESS: loaded ${timetable.examName} (ID: ${timetable.id})');
        print('[ExamTimetableBloc] Timetable data: examType=${timetable.examType}, academicYear=${timetable.academicYear}, status=${timetable.status}, createdBy=${timetable.createdBy}');
        emit(ExamTimetableLoaded(timetable: timetable));
      },
    );
  }

  /// Handler: GetExamTimetableEntriesEvent
  Future<void> _onGetExamTimetableEntries(
    GetExamTimetableEntriesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetExamTimetableEntries: timetableId=${event.timetableId}');

    // Don't emit loading state - load entries in the background
    final result = await _repository.getExamTimetableEntries(event.timetableId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] GetExamTimetableEntries ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (entries) {
        print('[ExamTimetableBloc] GetExamTimetableEntries SUCCESS: loaded ${entries.length} entries');
        emit(ExamTimetableEntriesLoaded(entries: entries));
      },
    );
  }

  /// Handler: CreateExamTimetableEvent
  Future<void> _onCreateExamTimetable(
    CreateExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] CreateExamTimetable: examName=${event.timetable.examName}, examType="${event.timetable.examType}", tenantId=${event.timetable.tenantId}');
    print('[ExamTimetableBloc] examType value: "${event.timetable.examType}", length=${event.timetable.examType.length}, is empty=${event.timetable.examType.isEmpty}');
    emit(const ExamTimetableLoading(message: 'Creating timetable...'));

    final result = await _createExamTimetableUsecase(
      params: CreateExamTimetableParams(timetable: event.timetable),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] CreateExamTimetable ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (timetable) {
        print('[ExamTimetableBloc] CreateExamTimetable SUCCESS: created timetable=${timetable.id}');
        emit(ExamTimetableCreated(timetable: timetable));
      },
    );
  }

  /// Handler: UpdateExamTimetableEvent
  Future<void> _onUpdateExamTimetable(
    UpdateExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Updating timetable...'));

    final result = await _repository.updateExamTimetable(event.timetable);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (timetable) => emit(ExamTimetableUpdated(timetable: timetable)),
    );
  }

  /// Handler: PublishExamTimetableEvent
  Future<void> _onPublishExamTimetable(
    PublishExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] Publishing timetable: ${event.timetableId}');
    emit(const ExamTimetableLoading(message: 'Publishing timetable...'));

    final result = await _publishExamTimetableUsecase(
      params: PublishExamTimetableParams(timetableId: event.timetableId),
    );

    result.fold(
      (failure) {
        print('[ExamTimetableBloc] Publish FAILED: ${failure.message}');
        if (failure is ValidationFailure) {
          // ignore: unchecked_use_of_nullable_value
          final errors = failure.message.split('\n');
          emit(ExamTimetablePublicationError(validationErrors: errors));
        } else {
          // ignore: unchecked_use_of_nullable_value
          emit(ExamTimetableError(message: failure.message));
        }
      },
      (timetable) {
        print('[ExamTimetableBloc] Publish SUCCESS: ${timetable.examName}');
        emit(ExamTimetablePublished(timetable: timetable));
      },
    );
  }

  /// Handler: ArchiveExamTimetableEvent
  Future<void> _onArchiveExamTimetable(
    ArchiveExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Archiving timetable...'));

    final result = await _repository.archiveExamTimetable(event.timetableId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (timetable) => emit(ExamTimetableArchived(timetable: timetable)),
    );
  }

  /// Handler: DeleteExamTimetableEvent
  Future<void> _onDeleteExamTimetable(
    DeleteExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] Deleting timetable: ${event.timetableId}');
    emit(const ExamTimetableLoading(message: 'Deleting timetable...'));

    final result = await _repository.deleteExamTimetable(event.timetableId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] Delete FAILED: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (_) {
        print('[ExamTimetableBloc] Delete SUCCESS: ${event.timetableId}');
        emit(ExamTimetableDeleted(timetableId: event.timetableId));
      },
    );
  }

  /// Handler: AddExamTimetableEntryEvent
  Future<void> _onAddExamTimetableEntry(
    AddExamTimetableEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Adding entry...'));

    final result = await _addExamTimetableEntryUsecase(
      params: AddExamTimetableEntryParams(entry: event.entry),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (entry) => emit(ExamTimetableEntryAdded(entry: entry)),
    );
  }

  /// Handler: UpdateExamTimetableEntryEvent
  Future<void> _onUpdateExamTimetableEntry(
    UpdateExamTimetableEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Updating entry...'));

    final result = await _repository.updateExamTimetableEntry(event.entry);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (entry) => emit(ExamTimetableEntryUpdated(entry: entry)),
    );
  }

  /// Handler: DeleteExamTimetableEntryEvent
  Future<void> _onDeleteExamTimetableEntry(
    DeleteExamTimetableEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Deleting entry...'));

    final result = await _repository.deleteExamTimetableEntry(event.entryId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (_) => emit(ExamTimetableEntryDeleted(entryId: event.entryId)),
    );
  }

  /// Handler: ValidateExamTimetableEvent
  Future<void> _onValidateExamTimetable(
    ValidateExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Validating timetable...'));

    final result = await _validateExamTimetableUsecase(
      params: ValidateExamTimetableParams(timetableId: event.timetableId),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (errors) => emit(ExamTimetableValidated(validationErrors: errors)),
    );
  }

  /// Handler: CheckDuplicateEntryEvent
  Future<void> _onCheckDuplicateEntry(
    CheckDuplicateEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    final result = await _repository.checkDuplicateEntry(
      event.timetableId,
      event.gradeId,
      event.subjectId,
      event.examDate,
      event.section,
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (isDuplicate) {
        if (isDuplicate) {
          emit(DuplicateEntryError(
            gradeId: event.gradeId,
            subjectId: event.subjectId,
            section: event.section,
            examDate: event.examDate,
          ));
        } else {
          emit(DuplicateEntryChecked(isDuplicate: false));
        }
      },
    );
  }

  /// Handler: CreateExamCalendarEvent
  Future<void> _onCreateExamCalendar(
    CreateExamCalendarEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Creating calendar...'));

    final result = await _repository.createExamCalendar(event.calendar);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (calendar) => emit(ExamCalendarCreated(calendar: calendar)),
    );
  }

  /// Handler: UpdateExamCalendarEvent
  Future<void> _onUpdateExamCalendar(
    UpdateExamCalendarEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading(message: 'Updating calendar...'));

    final result = await _repository.updateExamCalendar(event.calendar);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) => emit(ExamTimetableError(message: failure.message)),
      (calendar) => emit(ExamCalendarUpdated(calendar: calendar)),
    );
  }

  /// Handler: GetTimetableGradesAndSectionsEvent
  ///
  /// Fetches grades and sections from database respecting school-specific structure
  /// This replaces hardcoded mock data with real academic structure
  Future<void> _onGetTimetableGradesAndSections(
    GetTimetableGradesAndSectionsEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetTimetableGradesAndSections: tenantId=${event.tenantId}');
    emit(const ExamTimetableLoading(message: 'Loading grades and sections...'));

    final result = await _getTimetableGradesAndSectionsUsecase(
      params: GetTimetableGradesAndSectionsParams(tenantId: event.tenantId),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] GetTimetableGradesAndSections ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (gradesData) {
        print('[ExamTimetableBloc] GetTimetableGradesAndSections SUCCESS: loaded ${gradesData.grades.length} grades');
        emit(TimetableGradesAndSectionsLoaded(gradesData: gradesData));
      },
    );
  }

  /// Handler: LoadValidSubjectsEvent
  ///
  /// Fetches valid subjects for selected grade-section combinations
  /// Used in Step 3 wizard to populate Step 4 subject dropdowns
  /// Results in ValidSubjectsLoaded state with map of valid subjects per grade-section
  Future<void> _onLoadValidSubjects(
    LoadValidSubjectsEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] LoadValidSubjects: tenantId=${event.tenantId}, selectedGradeSectionIds=${event.selectedGradeSectionIds.join(", ")}');
    emit(const ExamTimetableLoading(message: 'Loading valid subjects...'));

    final result = await _getValidSubjectsUsecase(
      GetValidSubjectsForGradeSelectionParams(
        tenantId: event.tenantId,
        selectedGradeSectionIds: event.selectedGradeSectionIds,
      ),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] LoadValidSubjects ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (validSubjectsMap) {
        print('[ExamTimetableBloc] LoadValidSubjects SUCCESS: loaded subjects for ${validSubjectsMap.length} grade-sections');
        emit(ValidSubjectsLoaded(validSubjectsPerGradeSection: validSubjectsMap));
      },
    );
  }

  /// Handler: ClearErrorEvent
  Future<void> _onClearError(
    ClearErrorEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableInitial());
  }

  /// Handler: ResetExamTimetableEvent
  Future<void> _onResetState(
    ResetExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableInitial());
  }

  // ===== EXAM ENTRY HANDLERS =====

  /// Handler: GetExamEntriesEvent
  Future<void> _onGetExamEntries(
    GetExamEntriesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] GetExamEntries: timetableId=${event.timetableId}');
    emit(const ExamTimetableLoading(message: 'Loading exam entries...'));

    // TODO: Wire up the GetExamEntriesUsecase after registering it in DI
    // For now, emit empty list
    emit(const ExamEntriesLoaded(entries: []));
  }

  /// Handler: AddExamEntryEvent
  Future<void> _onAddExamEntry(
    AddExamEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] AddExamEntry: ${event.subjectId} for Grade ${event.gradeId}-${event.section}');
    emit(const ExamTimetableLoading(message: 'Adding exam entry...'));

    // Create entry entity for submission
    // TODO: gradeSectionId should come from user selection in Step 2
    const uuid = Uuid();
    final entry = ExamTimetableEntryEntity(
      id: null,
      tenantId: event.tenantId,
      timetableId: event.timetableId,
      gradeSectionId: uuid.v4(), // Placeholder - should be selected from grade_sections
      gradeId: event.gradeId,
      section: event.section,
      subjectId: event.subjectId,
      examDate: event.examDate,
      startTime: event.startTime,
      endTime: event.endTime,
      durationMinutes: event.durationMinutes,
      createdAt: DateTime.now(),
    );

    // Call use case to add entry (validates and saves to backend)
    final result = await _addExamTimetableEntryUsecase(
      params: AddExamTimetableEntryParams(entry: entry),
    );

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] AddExamEntry ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (addedEntry) {
        print('[ExamTimetableBloc] AddExamEntry SUCCESS: ${addedEntry.id}');
        emit(ExamEntryAdded(entry: addedEntry));
      },
    );
  }

  /// Handler: DeleteExamEntryEvent
  Future<void> _onDeleteExamEntry(
    DeleteExamEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    print('[ExamTimetableBloc] DeleteExamEntry: entryId=${event.entryId}');
    emit(const ExamTimetableLoading(message: 'Deleting exam entry...'));

    // Call repository to delete entry
    final result = await _repository.deleteExamTimetableEntry(event.entryId);

    result.fold(
      // ignore: unchecked_use_of_nullable_value
      (failure) {
        print('[ExamTimetableBloc] DeleteExamEntry ERROR: ${failure.message}');
        emit(ExamTimetableError(message: failure.message));
      },
      (_) {
        print('[ExamTimetableBloc] DeleteExamEntry SUCCESS: ${event.entryId}');
        emit(ExamEntryDeleted(entryId: event.entryId));
      },
    );
  }
}
