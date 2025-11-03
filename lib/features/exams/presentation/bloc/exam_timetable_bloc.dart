import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/exam_timetable_repository.dart';
import '../../domain/services/timetable_validation_service.dart';
import '../../domain/usecases/load_exam_timetables_usecase.dart';
import '../../domain/usecases/create_exam_timetable_usecase.dart';
import '../../domain/usecases/add_timetable_entry_usecase.dart';
import '../../domain/usecases/validate_timetable_for_publishing_usecase.dart';
import '../../domain/usecases/publish_exam_timetable_usecase.dart';
import '../../domain/usecases/delete_exam_timetable_usecase.dart';
import 'exam_timetable_event.dart';
import 'exam_timetable_state.dart';

/// BLoC for managing exam timetables
class ExamTimetableBloc extends Bloc<ExamTimetableEvent, ExamTimetableState> {
  final LoadExamTimetablesUseCase loadExamTimetablesUseCase;
  final CreateExamTimetableUseCase createExamTimetableUseCase;
  final AddTimetableEntryUseCase addTimetableEntryUseCase;
  final ValidateTimetableForPublishingUseCase validateTimetableUseCase;
  final PublishExamTimetableUseCase publishTimetableUseCase;
  final DeleteExamTimetableUseCase deleteTimetableUseCase;
  final TimetableValidationService validationService;
  final ExamTimetableRepository repository;

  ExamTimetableBloc({
    required this.loadExamTimetablesUseCase,
    required this.createExamTimetableUseCase,
    required this.addTimetableEntryUseCase,
    required this.validateTimetableUseCase,
    required this.publishTimetableUseCase,
    required this.deleteTimetableUseCase,
    required this.validationService,
    required this.repository,
  }) : super(const ExamTimetableInitial()) {
    on<LoadExamTimetablesEvent>(_onLoadExamTimetables);
    on<CreateExamTimetableEvent>(_onCreateExamTimetable);
    on<AddTimetableEntryEvent>(_onAddTimetableEntry);
    on<GetTimetableEntriesEvent>(_onGetTimetableEntries);
    on<ValidateTimetableEvent>(_onValidateTimetable);
    on<PublishTimetableEvent>(_onPublishTimetable);
    on<DeleteTimetableEvent>(_onDeleteTimetable);
    on<RefreshTimetablesEvent>(_onRefreshTimetables);
  }

  /// Load exam timetables
  Future<void> _onLoadExamTimetables(
    LoadExamTimetablesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableLoading());

    final result = await loadExamTimetablesUseCase(
      tenantId: event.tenantId,
      academicYear: event.academicYear,
      status: event.status,
    );

    result.fold(
      (failure) => emit(ExamTimetableError(failure.message)),
      (timetables) {
        if (timetables.isEmpty) {
          emit(const ExamTimetableEmpty());
        } else {
          emit(ExamTimetableLoaded(timetables));
        }
      },
    );
  }

  /// Create exam timetable
  Future<void> _onCreateExamTimetable(
    CreateExamTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ExamTimetableCreating());

    final result = await createExamTimetableUseCase(
      tenantId: event.tenantId,
      createdBy: event.createdBy,
      examCalendarId: event.examCalendarId,
      examName: event.examName,
      examType: event.examType,
      examNumber: event.examNumber,
      academicYear: event.academicYear,
    );

    result.fold(
      (failure) => emit(ExamTimetableCreationError(failure.message)),
      (timetable) {
        emit(ExamTimetableCreated(timetable));
      },
    );
  }

  /// Add entry to timetable
  Future<void> _onAddTimetableEntry(
    AddTimetableEntryEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const AddingTimetableEntry());

    final result = await addTimetableEntryUseCase(
      tenantId: event.tenantId,
      timetableId: event.timetableId,
      gradeId: event.gradeId,
      subjectId: event.subjectId,
      section: event.section,
      examDate: event.examDate,
      startTime: event.startTime,
      endTime: event.endTime,
    );

    result.fold(
      (failure) => emit(AddTimetableEntryError(failure.message)),
      (entry) {
        emit(TimetableEntryAdded(entry));
      },
    );
  }

  /// Get timetable entries
  Future<void> _onGetTimetableEntries(
    GetTimetableEntriesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const TimetableEntriesLoading());

    final result = await repository.getTimetableEntries(event.timetableId);

    result.fold(
      (failure) => emit(TimetableEntriesError(failure.message)),
      (entries) {
        if (entries.isEmpty) {
          emit(const TimetableEntriesEmpty());
        } else {
          emit(TimetableEntriesLoaded(entries));
        }
      },
    );
  }

  /// Validate timetable for publishing
  Future<void> _onValidateTimetable(
    ValidateTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const ValidatingTimetable());

    // Get entries
    final entriesResult = await repository.getTimetableEntries(event.timetableId);

    final entries = entriesResult.fold(
      (failure) {
        emit(TimetableValidationFailed([failure.message]));
        return <dynamic>[];
      },
      (entries) => entries,
    );

    if (entries.isEmpty) {
      emit(const TimetableValidationFailed(
        ['Timetable must have at least 1 entry'],
      ));
      return;
    }

    // Validate entries
    final validationResult =
        await validationService.validateEntries(entries);

    validationResult.fold(
      (failure) => emit(TimetableValidationFailed([failure.message])),
      (validationErrors) {
        if (validationErrors.isEmpty) {
          emit(const TimetableValidationSuccess());
        } else {
          final errorMessages = validationErrors
              .map((e) => '${e.field}: ${e.message}')
              .toList();
          final warnings = validationErrors
              .where((e) => e.severity == 'warning')
              .map((e) => e.message)
              .toList();

          if (validationErrors.any((e) => e.severity == 'error')) {
            emit(TimetableValidationFailed(errorMessages));
          } else {
            emit(TimetableValidationSuccess(warnings: warnings));
          }
        }
      },
    );
  }

  /// Publish timetable (with paper auto-creation)
  Future<void> _onPublishTimetable(
    PublishTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(const PublishingTimetable());

    final result = await publishTimetableUseCase(timetableId: event.timetableId);

    result.fold(
      (failure) => emit(PublishTimetableError(failure.message)),
      (_) async {
        // Get updated timetable
        final timetableResult =
            await repository.getTimetableById(event.timetableId);

        timetableResult.fold(
          (failure) => emit(PublishTimetableError(failure.message)),
          (timetable) {
            if (timetable != null) {
              emit(TimetablePublished(timetable: timetable));
            } else {
              emit(const PublishTimetableError('Timetable not found'));
            }
          },
        );
      },
    );
  }

  /// Delete timetable
  Future<void> _onDeleteTimetable(
    DeleteTimetableEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    emit(DeletingTimetable(event.timetableId));

    final result = await deleteTimetableUseCase(timetableId: event.timetableId);

    result.fold(
      (failure) => emit(DeleteTimetableError(failure.message)),
      (_) => emit(TimetableDeleted(event.timetableId)),
    );
  }

  /// Refresh timetables
  Future<void> _onRefreshTimetables(
    RefreshTimetablesEvent event,
    Emitter<ExamTimetableState> emit,
  ) async {
    add(LoadExamTimetablesEvent(tenantId: event.tenantId));
  }
}
