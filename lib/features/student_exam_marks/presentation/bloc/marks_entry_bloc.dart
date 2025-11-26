import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/student_mark_entry_dto.dart';
import '../../domain/usecases/get_marks_for_timetable_entry_usecase.dart';
import '../../domain/usecases/save_marks_as_draft_usecase.dart';
import '../../domain/usecases/submit_marks_usecase.dart';
import 'marks_entry_event.dart';
import 'marks_entry_state.dart';

class MarksEntryBloc extends Bloc<MarksEntryEvent, MarksEntryState> {
  final GetMarksForTimetableEntryUsecase _getMarksUsecase;
  final SaveMarksAsDraftUsecase _saveMarksUsecase;
  final SubmitMarksUsecase _submitMarksUsecase;

  MarksEntryBloc({
    required GetMarksForTimetableEntryUsecase getMarksUsecase,
    required SaveMarksAsDraftUsecase saveMarksUsecase,
    required SubmitMarksUsecase submitMarksUsecase,
  })  : _getMarksUsecase = getMarksUsecase,
        _saveMarksUsecase = saveMarksUsecase,
        _submitMarksUsecase = submitMarksUsecase,
        super(const MarksEntryInitial()) {
    debugPrint('=== MarksEntryBloc constructor called ===');
    on<LoadMarksForTimetableEvent>(_onLoadMarks);
    on<UpdateStudentMarkEvent>(_onUpdateStudentMark);
    on<SaveMarksAsDraftEvent>(_onSaveMarksAsDraft);
    on<SubmitMarksEvent>(_onSubmitMarksWrapper);
    on<ClearMarksEntryEvent>(_onClearMarksEntry);
    debugPrint('=== Event handlers registered ===');
  }

  Future<void> _onLoadMarks(
    LoadMarksForTimetableEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    emit(const MarksEntryLoading());

    final result = await _getMarksUsecase.call(
      examTimetableEntryId: event.examTimetableEntryId,
    );

    result.fold(
      (failure) {
        emit(MarksEntryError(message: failure.message));
      },
      (marks) {
        // Convert entities to editable DTOs
        final editableMarks = marks
            .map((mark) => StudentMarkEntryDto(
          studentId: mark.studentId,
          studentName: mark.studentName ?? 'Unknown',
          studentRollNumber: mark.studentRollNumber ?? 'N/A',
          totalMarks: mark.totalMarks,
          status: mark.status,
          remarks: mark.remarks,
        ))
            .toList();

        emit(MarksEntryLoaded(
          marks: marks,
          editableMarks: editableMarks,
          isDraft: marks.isNotEmpty ? marks.first.isDraft : true,
          examTimetableEntryId: event.examTimetableEntryId,
        ));
      },
    );
  }

  Future<void> _onUpdateStudentMark(
    UpdateStudentMarkEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    if (state is MarksEntryLoaded) {
      final currentState = state as MarksEntryLoaded;

      // Update the specific student mark
      final updatedMarks = List<StudentMarkEntryDto>.from(currentState.editableMarks);
      if (event.studentIndex < updatedMarks.length) {
        final oldMark = updatedMarks[event.studentIndex];
        updatedMarks[event.studentIndex] = StudentMarkEntryDto(
          studentId: oldMark.studentId,
          studentName: oldMark.studentName,
          studentRollNumber: oldMark.studentRollNumber,
          totalMarks: event.totalMarks,
          status: event.status,
          remarks: event.remarks ?? oldMark.remarks,
        );
      }

      emit(currentState.copyWith(editableMarks: updatedMarks));
    }
  }

  Future<void> _onSaveMarksAsDraft(
    SaveMarksAsDraftEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    emit(const MarksSubmitting(message: 'Saving marks as draft...'));

    final request = BulkMarksEntryRequest(
      examTimetableEntryId: event.examTimetableEntryId,
      marks: event.marks,
      enteredBy: event.teacherId,
      isDraft: true,
    );

    final result = await _saveMarksUsecase.call(request: request);

    result.fold(
      (failure) {
        emit(MarksEntryError(message: failure.message));
      },
      (response) {
        emit(MarksSavedAsDraft(
          message: response.message,
          totalRecords: response.totalRecordsUpdated,
        ));
        // Re-emit loaded state after saving
        add(LoadMarksForTimetableEvent(examTimetableEntryId: event.examTimetableEntryId));
      },
    );
  }

  Future<void> _onSubmitMarksWrapper(
    SubmitMarksEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    debugPrint('=== WRAPPER: SubmitMarksEvent received ===');
    return _onSubmitMarks(event, emit);
  }

  Future<void> _onSubmitMarks(
    SubmitMarksEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    debugPrint('=== BLOC: _onSubmitMarks called ===');
    debugPrint('Event: ${event.toString()}');
    debugPrint('Exam Timetable ID: ${event.examTimetableEntryId}');
    debugPrint('Teacher ID: ${event.teacherId}');
    debugPrint('Total marks: ${event.marks.length}');

    emit(const MarksSubmitting(message: 'Submitting marks...'));
    debugPrint('Emitted MarksSubmitting state');

    final request = BulkMarksEntryRequest(
      examTimetableEntryId: event.examTimetableEntryId,
      marks: event.marks,
      enteredBy: event.teacherId,
      isDraft: false,
    );

    debugPrint('Created BulkMarksEntryRequest');
    debugPrint('Calling _submitMarksUsecase...');

    final result = await _submitMarksUsecase.call(request: request);

    debugPrint('Result received from usecase');

    result.fold(
      (failure) {
        debugPrint('Submission FAILED: ${failure.message}');
        emit(MarksEntryError(message: failure.message));
      },
      (response) {
        debugPrint('Submission SUCCESS: ${response.message}');
        debugPrint('Total records updated: ${response.totalRecordsUpdated}');
        emit(MarksSubmitted(
          message: response.message,
          totalRecords: response.totalRecordsUpdated,
        ));
        // Re-emit loaded state after submission
        debugPrint('Re-loading marks after submission...');
        add(LoadMarksForTimetableEvent(examTimetableEntryId: event.examTimetableEntryId));
      },
    );
  }

  Future<void> _onClearMarksEntry(
    ClearMarksEntryEvent event,
    Emitter<MarksEntryState> emit,
  ) async {
    emit(const MarksEntryInitial());
  }
}
