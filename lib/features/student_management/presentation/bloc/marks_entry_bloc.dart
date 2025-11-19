import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/interfaces/ilogger.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/entities/student_exam_marks_entity.dart';
import 'package:papercraft/features/student_management/domain/services/marks_validation_service.dart';
import 'package:papercraft/features/student_management/domain/usecases/get_students_by_grade_section_usecase.dart';
import 'package:papercraft/features/student_management/domain/usecases/marks_usecases.dart';

part 'marks_entry_event.dart';
part 'marks_entry_state.dart';

class MarksEntryBloc extends Bloc<MarksEntryEvent, MarksEntryState> {
  final GetStudentsByGradeSectionUseCase getStudentsUseCase;
  final GetExamMarksUseCase getExamMarksUseCase;
  final AddExamMarksUseCase addMarksUseCase;
  final UpdateStudentMarksUseCase updateMarksUseCase;
  final SubmitMarksUseCase submitMarksUseCase;
  final BulkUploadMarksUseCase bulkUploadMarksUseCase;
  final GetMarksStatisticsUseCase getStatisticsUseCase;
  final MarksValidationService validationService;
  final ILogger logger;

  MarksEntryBloc({
    required this.getStudentsUseCase,
    required this.getExamMarksUseCase,
    required this.addMarksUseCase,
    required this.updateMarksUseCase,
    required this.submitMarksUseCase,
    required this.bulkUploadMarksUseCase,
    required this.getStatisticsUseCase,
    required this.validationService,
    required this.logger,
  }) : super(const MarksEntryInitial()) {
    on<InitializeMarksEntry>(_onInitialize);
    on<UpdateStudentMarkValue>(_onUpdateMark);
    on<UpdateStudentMarkStatus>(_onUpdateStatus);
    on<SubmitExamMarks>(_onSubmitMarks);
    on<BulkUploadExamMarks>(_onBulkUpload);
    on<ReloadDraftMarks>(_onReloadDraft);
  }

  Future<void> _onInitialize(
    InitializeMarksEntry event,
    Emitter<MarksEntryState> emit,
  ) async {
    emit(const MarksEntryLoading());

    try {
      // Get all students for the grade section
      final studentsResult = await getStudentsUseCase(
        GetStudentsParams(gradeSectionId: event.gradeSectionId),
      );

      final students = studentsResult.fold(
        (failure) => <StudentEntity>[],
        (data) => data,
      );

      if (students.isEmpty) {
        emit(const MarksEntryError('No students found in this section'));
        return;
      }

      // Try to load existing draft marks
      final marksResult = await getExamMarksUseCase(event.examTimetableEntryId);

      final existingMarks = marksResult.fold(
        (failure) => <StudentExamMarksEntity>[],
        (data) => data,
      );

      // Create marks map
      final marksMap = <String, StudentMarkEntry>{};
      for (var student in students) {
        final existing = existingMarks.firstWhereOrNull(
          (m) => m.studentId == student.id,
        );

        marksMap[student.id] = StudentMarkEntry(
          studentId: student.id,
          marks: existing?.totalMarks ?? 0.0,
          status: existing?.status ?? StudentMarkStatus.present,
          remarks: existing?.remarks,
        );
      }

      emit(MarksEntryReady(
        examTimetableEntryId: event.examTimetableEntryId,
        gradeSectionId: event.gradeSectionId,
        students: students,
        marksEntries: marksMap,
        isDraft: existingMarks.any((m) => m.isDraft),
      ));

      logger.info(
        'Marks entry initialized with ${students.length} students',
        category: 'MarksEntryBloc',
      );
    } catch (e) {
      logger.error(
        'Error initializing marks entry: ${e.toString()}',
        category: 'MarksEntryBloc',
      );
      emit(MarksEntryError(
        'Failed to initialize: ${e.toString()}',
      ));
    }
  }

  Future<void> _onUpdateMark(
    UpdateStudentMarkValue event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is! MarksEntryReady) return;

    final currentState = state as MarksEntryReady;

    // Validate marks
    final validationResult = await validationService.validateMarks(
      marks: event.marks,
      examTimetableEntryId: currentState.examTimetableEntryId,
      status: currentState.marksEntries[event.studentId]?.status ?? StudentMarkStatus.present,
    );

    validationResult.fold(
      (failure) {
        emit(MarkValidationError(failure.message));
        // Auto-revert to ready state after error
        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) {
            emit(currentState);
          }
        });
      },
      (_) {
        final updatedEntries = Map<String, StudentMarkEntry>.from(
          currentState.marksEntries,
        );
        final currentEntry = updatedEntries[event.studentId]!;
        updatedEntries[event.studentId] = currentEntry.copyWith(marks: event.marks);

        emit(currentState.copyWith(marksEntries: updatedEntries));
      },
    );
  }

  Future<void> _onUpdateStatus(
    UpdateStudentMarkStatus event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is! MarksEntryReady) return;

    final currentState = state as MarksEntryReady;

    final updatedEntries = Map<String, StudentMarkEntry>.from(
      currentState.marksEntries,
    );
    final currentEntry = updatedEntries[event.studentId]!;

    // If marking as not present, clear marks
    if (event.status != StudentMarkStatus.present) {
      updatedEntries[event.studentId] = currentEntry.copyWith(
        status: event.status,
        marks: 0.0,
      );
    } else {
      updatedEntries[event.studentId] = currentEntry.copyWith(
        status: event.status,
      );
    }

    emit(currentState.copyWith(marksEntries: updatedEntries));
  }

  Future<void> _onSubmitMarks(
    SubmitExamMarks event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is! MarksEntryReady) return;

    final currentState = state as MarksEntryReady;

    emit(const SubmittingMarks());

    try {
      // Validate all marks before submission
      final allMarksEntities = _convertToEntities(currentState);
      final validationResult = await validationService.validateAllMarks(
        allMarks: allMarksEntities,
        examTimetableEntryId: currentState.examTimetableEntryId,
      );

      if (validationResult.isLeft()) {
        final failure = validationResult.fold(
          (f) => f.message,
          (_) => 'Validation failed',
        );
        emit(MarksEntryError(failure));
        return;
      }

      // Submit marks
      final result = await submitMarksUseCase(
        currentState.examTimetableEntryId,
      );

      result.fold(
        (failure) {
          logger.error(
            'Failed to submit marks: ${failure.message}',
            category: 'MarksEntryBloc',
          );
          emit(MarksEntryError(failure.message));
        },
        (summary) {
          logger.info(
            'Marks submitted successfully. Total: ${summary.totalStudents}, Present: ${summary.markedPresent}',
            category: 'MarksEntryBloc',
          );
          emit(MarksSubmitted(summary));
        },
      );
    } catch (e) {
      logger.error(
        'Error submitting marks: ${e.toString()}',
        category: 'MarksEntryBloc',
      );
      emit(MarksEntryError('Failed to submit marks: ${e.toString()}'));
    }
  }

  Future<void> _onBulkUpload(
    BulkUploadExamMarks event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is! MarksEntryReady) return;

    final currentState = state as MarksEntryReady;

    emit(const BulkUploadingMarks());

    try {
      final result = await bulkUploadMarksUseCase(
        BulkUploadMarksParams(
          examTimetableEntryId: currentState.examTimetableEntryId,
          marksData: event.marksData,
        ),
      );

      result.fold(
        (failure) {
          logger.error(
            'Failed to bulk upload marks: ${failure.message}',
            category: 'MarksEntryBloc',
          );
          emit(BulkUploadFailed(failure.message));
          // Return to ready state
          emit(currentState);
        },
        (uploadedMarks) {
          logger.info(
            'Bulk uploaded ${uploadedMarks.length} marks',
            category: 'MarksEntryBloc',
          );

          // Reload from draft
          add(const ReloadDraftMarks());
        },
      );
    } catch (e) {
      logger.error(
        'Error bulk uploading marks: ${e.toString()}',
        category: 'MarksEntryBloc',
      );
      emit(BulkUploadFailed('Failed to bulk upload: ${e.toString()}'));
    }
  }

  Future<void> _onReloadDraft(
    ReloadDraftMarks event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is! MarksEntryReady) return;

    final currentState = state as MarksEntryReady;

    try {
      // Reload marks for this exam
      final marksResult = await getExamMarksUseCase(
        currentState.examTimetableEntryId,
      );

      final marks = marksResult.fold(
        (failure) => <StudentExamMarksEntity>[],
        (data) => data,
      );

      // Update entries with new data
      final updatedEntries = Map<String, StudentMarkEntry>.from(
        currentState.marksEntries,
      );

      for (var mark in marks) {
        if (updatedEntries.containsKey(mark.studentId)) {
          updatedEntries[mark.studentId] = StudentMarkEntry(
            studentId: mark.studentId,
            marks: mark.totalMarks,
            status: mark.status,
            remarks: mark.remarks,
          );
        }
      }

      emit(currentState.copyWith(marksEntries: updatedEntries));
    } catch (e) {
      logger.error(
        'Error reloading draft marks: ${e.toString()}',
        category: 'MarksEntryBloc',
      );
      // Continue with current state on error
    }
  }

  List<StudentExamMarksEntity> _convertToEntities(MarksEntryReady state) {
    final entities = <StudentExamMarksEntity>[];

    for (var entry in state.marksEntries.values) {
      // Find corresponding student
      final student = state.students.firstWhereOrNull(
        (s) => s.id == entry.studentId,
      );

      if (student != null) {
        entities.add(StudentExamMarksEntity(
          id: '',
          tenantId: student.tenantId,
          studentId: entry.studentId,
          examTimetableEntryId: state.examTimetableEntryId,
          totalMarks: entry.marks,
          status: entry.status,
          remarks: entry.remarks,
          enteredBy: '', // Will be set by usecase
          isDraft: false,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }

    return entities;
  }
}

// Extension to find first where
extension ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
