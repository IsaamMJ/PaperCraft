import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../domain/usecases/create_exam_timetable_with_entries_usecase.dart';
import '../../domain/usecases/get_exam_calendars_usecase.dart';
import '../../domain/usecases/get_grades_for_calendar_usecase.dart';
import '../../domain/usecases/map_grades_to_exam_calendar_usecase.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/usecases/get_grades_usecase.dart';
import '../../../catalog/domain/usecases/get_subjects_usecase.dart';
import '../../../catalog/domain/usecases/load_grade_sections_usecase.dart';
import 'exam_timetable_wizard_event.dart';
import 'exam_timetable_wizard_state.dart';

/// BLoC for managing the 3-step exam timetable wizard
class ExamTimetableWizardBloc
    extends Bloc<ExamTimetableWizardEvent, ExamTimetableWizardState> {
  final GetExamCalendarsUsecase getExamCalendars;
  final MapGradesToExamCalendarUsecase mapGradesToExamCalendar;
  final GetGradesForCalendarUsecase getGradesForCalendar;
  final CreateExamTimetableWithEntriesUsecase createExamTimetableWithEntries;
  final GetGradesUseCase getGrades;
  final GetSubjectsUseCase getSubjects;
  final LoadGradeSectionsUseCase loadGradeSections;

  /// Store the current user ID
  late String _currentUserId;

  ExamTimetableWizardBloc({
    required this.getExamCalendars,
    required this.mapGradesToExamCalendar,
    required this.getGradesForCalendar,
    required this.createExamTimetableWithEntries,
    required this.getGrades,
    required this.getSubjects,
    required this.loadGradeSections,
  }) : super(const WizardInitial()) {
    on<InitializeWizardEvent>(_onInitializeWizard);
    on<SelectExamCalendarEvent>(_onSelectExamCalendar);
    on<UpdateUserGradeSelectionEvent>(_onUpdateUserGradeSelection);
    on<SelectGradesEvent>(_onSelectGrades);
    on<AssignSubjectDateEvent>(_onAssignSubjectDate);
    on<RemoveSubjectAssignmentEvent>(_onRemoveSubjectAssignment);
    on<UpdateSubjectAssignmentEvent>(_onUpdateSubjectAssignment);
    on<SubmitWizardEvent>(_onSubmitWizard);
    on<GoBackEvent>(_onGoBack);
    on<ResetWizardEvent>(_onResetWizard);
  }

  /// Initialize wizard - load exam calendars for tenant
  Future<void> _onInitializeWizard(
    InitializeWizardEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    // Store the user ID for later use in submission
    _currentUserId = event.userId;

    emit(const WizardStep1State(isLoading: true));

    final result = await getExamCalendars(
      params: GetExamCalendarsParams(tenantId: event.tenantId),
    );

    result.fold(
      (failure) => emit(WizardStep1State(
        isLoading: false,
        error: failure.toString(),
      )),
      (calendars) => emit(WizardStep1State(
        calendars: calendars,
        isLoading: false,
      )),
    );
  }

  /// Step 1 → Step 2: Transition to grade selection
  Future<void> _onSelectExamCalendar(
    SelectExamCalendarEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    print('[WizardBloc] Step 1→2: SelectExamCalendar event received');
    print('[WizardBloc] Selected calendar: ${event.calendar.examName} (ID: ${event.calendar.id})');

    // Get current state for tenant info
    final currentState = state;
    String tenantId = '';

    if (currentState is WizardStep1State) {
      tenantId = event.calendar.tenantId;
    } else if (currentState is WizardStep2State) {
      tenantId = currentState.tenantId;
    } else if (currentState is WizardStep3State) {
      tenantId = currentState.tenantId;
    }

    print('[WizardBloc] TenantId: $tenantId');

    // Emit loading state
    print('[WizardBloc] Emitting WizardStep2State with isLoading=true');
    emit(WizardStep2State(
      tenantId: tenantId,
      selectedCalendar: event.calendar,
      isLoading: true,
    ));

    // Load available grades and check which are already selected
    print('[WizardBloc] Loading all grades...');
    final gradesResult = await getGrades();

    print('[WizardBloc] Grades result received: ${gradesResult.isRight() ? 'SUCCESS' : 'FAILURE'}');

    // Handle grades result
    await gradesResult.fold(
      (failure) async {
        print('[WizardBloc] FAILURE loading grades: $failure');
        emit(WizardStep2State(
          tenantId: tenantId,
          selectedCalendar: event.calendar,
          isLoading: false,
          error: failure.toString(),
        ));
      },
      (allGrades) async {
        print('[WizardBloc] SUCCESS: Loaded ${allGrades.length} grades');
        print('[WizardBloc] Checking for already mapped grades for calendar: ${event.calendar.id}');

        // Check if grades are already mapped (for resume scenario)
        await _loadMappedGradesAndEmit(
          tenantId: tenantId,
          allGrades: allGrades,
          calendar: event.calendar,
          emit: emit,
        );
      },
    );
  }

  /// Helper method to load mapped grades asynchronously
  /// This avoids the nested async callback issue in fold()
  Future<void> _loadMappedGradesAndEmit({
    required String tenantId,
    required List<GradeEntity> allGrades,
    required ExamCalendarEntity calendar,
    required Emitter<ExamTimetableWizardState> emit,
  }) async {
    print('[WizardBloc] Inside _loadMappedGradesAndEmit helper');
    print('[WizardBloc] Helper received allGrades count: ${allGrades.length}');

    final mappedResult = await getGradesForCalendar(
      GetGradesForCalendarParams(examCalendarId: calendar.id),
    );

    print('[WizardBloc] Mapped grades result: ${mappedResult.isRight() ? 'SUCCESS' : 'FAILURE'}');
    print('[WizardBloc] About to fold the result...');

    mappedResult.fold(
      (failure) {
        print('[WizardBloc] FAILURE checking mapped grades: $failure');
        emit(WizardStep2State(
          tenantId: tenantId,
          selectedCalendar: calendar,
          availableGrades: allGrades,
          isLoading: false,
          error: failure.toString(),
        ));
      },
      (alreadyMappedGradeIds) {
        print('[WizardBloc] SUCCESS: Found ${alreadyMappedGradeIds.length} already mapped grades');
        print('[WizardBloc] Emitting WizardStep2State with:');
        print('  - availableGrades: ${allGrades.length}');
        print('  - selectedGradeIds: ${alreadyMappedGradeIds.length}');
        print('  - isLoading: false');

        final newState = WizardStep2State(
          tenantId: tenantId,
          selectedCalendar: calendar,
          availableGrades: allGrades,
          selectedGradeIds: alreadyMappedGradeIds,
          isLoading: false,
        );

        print('[WizardBloc] About to emit: ${newState.availableGrades.length} grades');
        emit(newState);
        print('[WizardBloc] State emitted successfully');
      },
    );
  }

  /// Update user's grade section selection locally (Step 2 checkbox changes)
  Future<void> _onUpdateUserGradeSelection(
    UpdateUserGradeSelectionEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;

    print('[WizardBloc] User updated grade section selection: ${event.selectedGradeSectionIds.length} sections selected');

    // Update the state with the new user selection
    emit(step2State.copyWith(selectedGradeIds: event.selectedGradeSectionIds));
  }

  /// Step 2 → Step 3: Expand grades to sections and transition to subject assignment
  Future<void> _onSelectGrades(
    SelectGradesEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;

    emit(step2State.copyWith(isLoading: true, error: null));

    // Validate at least one grade selected (note: event.gradeSectionIds contains grade IDs from UI)
    if (event.gradeSectionIds.isEmpty) {
      emit(WizardValidationErrorState(
        errors: ['Please select at least one grade'],
        step: 'step_2',
      ));
      return;
    }

    print('[WizardBloc] User selected ${event.gradeSectionIds.length} grades, expanding to sections...');

    // Expand selected grades to all their sections
    final List<String> allSectionIds = [];
    final gradeSectionMapping = <String, String>{};

    for (final gradeId in event.gradeSectionIds) {
      print('[WizardBloc] Loading sections for grade: $gradeId');

      final sectionsResult = await loadGradeSections(
        tenantId: step2State.tenantId,
        gradeId: gradeId,
      );

      sectionsResult.fold(
        (failure) {
          print('[WizardBloc] FAILURE loading sections for grade $gradeId: $failure');
        },
        (sections) {
          print('[WizardBloc] Grade $gradeId has ${sections.length} sections');
          for (final section in sections) {
            allSectionIds.add(section.id);
            gradeSectionMapping[gradeId] = section.id;
            print('[WizardBloc] Added section: ${section.sectionName} (${section.id}) for grade $gradeId');
          }
        },
      );
    }

    if (allSectionIds.isEmpty) {
      emit(step2State.copyWith(
        isLoading: false,
        error: 'Selected grades have no sections configured',
      ));
      return;
    }

    // Map all expanded grade sections to calendar
    final result = await mapGradesToExamCalendar(
      MapGradesToExamCalendarParams(
        tenantId: step2State.tenantId,
        examCalendarId: event.examCalendarId,
        gradeSectionIds: allSectionIds,
      ),
    );

    print('[WizardBloc] Grade section mapping result: ${result.isRight() ? 'SUCCESS' : 'FAILURE'}');

    await result.fold(
      (failure) async {
        print('[WizardBloc] FAILURE mapping grade sections: $failure');
        emit(step2State.copyWith(
          isLoading: false,
          error: failure.toString(),
        ));
      },
      (mappings) async {
        print('[WizardBloc] SUCCESS mapping ${mappings.length} grade sections, loading subjects...');

        // Load subjects for the selected grades
        final subjectsResult = await getSubjects();

        print('[WizardBloc] Subjects result: ${subjectsResult.isRight() ? 'SUCCESS' : 'FAILURE'}');

        await subjectsResult.fold(
          (failure) async {
            print('[WizardBloc] FAILURE loading subjects: $failure');
            emit(step2State.copyWith(
              isLoading: false,
              error: failure.toString(),
            ));
          },
          (subjects) async {
            print('[WizardBloc] SUCCESS loaded ${subjects.length} subjects, emitting WizardStep3State');
            emit(WizardStep3State(
              tenantId: step2State.tenantId,
              selectedCalendar: step2State.selectedCalendar,
              selectedGradeIds: event.gradeSectionIds, // Store original grade IDs for reference
              subjects: subjects,
              gradeSectionMapping: gradeSectionMapping,
              isLoading: false,
            ));
            print('[WizardBloc] WizardStep3State emitted successfully with ${allSectionIds.length} grade sections');
          },
        );
      },
    );
  }

  /// Step 3: Assign a subject to an exam date
  Future<void> _onAssignSubjectDate(
    AssignSubjectDateEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;
    final step3State = state as WizardStep3State;

    // Validate date is within calendar range
    if (event.examDate.isBefore(step3State.selectedCalendar.plannedStartDate) ||
        event.examDate.isAfter(step3State.selectedCalendar.plannedEndDate)) {
      emit(WizardValidationErrorState(
        errors: [
          'Exam date must be between ${step3State.selectedCalendar.plannedStartDate.toLocal()} '
          'and ${step3State.selectedCalendar.plannedEndDate.toLocal()}'
        ],
        step: 'step_3',
      ));
      return;
    }

    // Calculate duration
    final startMinutes = event.startTime.hour * 60 + event.startTime.minute;
    final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      emit(WizardValidationErrorState(
        errors: ['End time must be after start time'],
        step: 'step_3',
      ));
      return;
    }

    // MVP: Use the first selected grade's first available section
    // Grade section mapping was populated in _onSelectGrades
    if (step3State.selectedGradeIds.isEmpty) {
      emit(WizardValidationErrorState(
        errors: ['No grades selected'],
        step: 'step_3',
      ));
      return;
    }

    final firstGradeId = step3State.selectedGradeIds[0];
    final gradeSectionId = step3State.gradeSectionMapping[firstGradeId];

    if (gradeSectionId == null || gradeSectionId.isEmpty) {
      emit(WizardValidationErrorState(
        errors: ['Grade section mapping not found for grade $firstGradeId. Please go back and reselect grades.'],
        step: 'step_3',
      ));
      return;
    }

    print('[WizardBloc] Creating entry with gradeSectionId: $gradeSectionId for grade: $firstGradeId');

    // Create entry with actual gradeSectionId from the mapping
    final newEntry = ExamTimetableEntryEntity(
      id: null, // Let database generate UUID
      tenantId: step3State.tenantId,
      timetableId: '',
      gradeSectionId: gradeSectionId, // Real grade_section_id from database
      gradeId: firstGradeId,
      section: 'A', // Default section (denormalized from grade_sections)
      subjectId: event.subjectId,
      examDate: event.examDate,
      startTime: Duration(hours: event.startTime.hour, minutes: event.startTime.minute),
      endTime: Duration(hours: event.endTime.hour, minutes: event.endTime.minute),
      durationMinutes: durationMinutes,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Check if subject already assigned
    final existingIndex =
        step3State.entries.indexWhere((e) => e.subjectId == event.subjectId);
    List<ExamTimetableEntryEntity> updatedEntries;

    if (existingIndex >= 0) {
      // Replace existing
      updatedEntries = List.from(step3State.entries);
      updatedEntries[existingIndex] = newEntry;
    } else {
      // Add new
      updatedEntries = [...step3State.entries, newEntry];
    }

    emit(step3State.copyWith(entries: updatedEntries));
  }

  /// Step 3: Remove a subject assignment
  Future<void> _onRemoveSubjectAssignment(
    RemoveSubjectAssignmentEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;
    final step3State = state as WizardStep3State;

    final updatedEntries =
        step3State.entries.where((e) => e.subjectId != event.subjectId).toList();

    emit(step3State.copyWith(entries: updatedEntries));
  }

  /// Step 3: Update a subject assignment
  Future<void> _onUpdateSubjectAssignment(
    UpdateSubjectAssignmentEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;

    // Remove and re-add with new values
    add(RemoveSubjectAssignmentEvent(subjectId: event.subjectId));
    add(AssignSubjectDateEvent(
      subjectId: event.subjectId,
      examDate: event.newExamDate,
      startTime: event.newStartTime,
      endTime: event.newEndTime,
    ));
  }

  /// Step 3 → Complete: Submit wizard and create timetable
  Future<void> _onSubmitWizard(
    SubmitWizardEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;
    final step3State = state as WizardStep3State;

    print('[WizardBloc] Submitting wizard with ${step3State.entries.length} entries');
    for (var i = 0; i < step3State.entries.length; i++) {
      final entry = step3State.entries[i];
      print('[WizardBloc] Entry $i: subject=${entry.subjectId}, grade=${entry.gradeId}, date=${entry.examDate.toString().split(' ')[0]}, id=${entry.id}');
    }

    emit(step3State.copyWith(isLoading: true, error: null));

    // Create timetable with entries (no validation - allow partial subject assignments)
    final result = await createExamTimetableWithEntries(
      CreateExamTimetableWithEntriesParams(
        tenantId: step3State.tenantId,
        examCalendarId: step3State.selectedCalendar.id,
        examName: step3State.selectedCalendar.examName,
        examType: step3State.selectedCalendar.examType,
        academicYear: '2024-25', // TODO: Get from user state
        createdByUserId: _currentUserId, // Now using the stored user ID
        entries: step3State.entries,
      ),
    );

    result.fold(
      (failure) {
        print('[WizardBloc] Submit failed: $failure');
        emit(step3State.copyWith(
          isLoading: false,
          error: failure.toString(),
        ));
      },
      (timetable) {
        print('[WizardBloc] Submit succeeded: timetable=${timetable.id}');
        emit(WizardCompletedState(
          timetableId: timetable.id,
          examName: timetable.examName,
          message: 'Exam timetable created successfully!',
        ));
      },
    );
  }

  /// Go back to previous step
  Future<void> _onGoBack(
    GoBackEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    final currentState = state;

    if (currentState is WizardStep3State) {
      // Go back to Step 2
      emit(WizardStep2State(
        tenantId: currentState.tenantId,
        selectedCalendar: currentState.selectedCalendar,
        selectedGradeIds: currentState.selectedGradeIds,
      ));
    } else if (currentState is WizardStep2State) {
      // Go back to Step 1
      emit(WizardStep1State(
        selectedCalendar: currentState.selectedCalendar,
      ));
    }
    // Can't go back from Step 1
  }

  /// Reset entire wizard
  Future<void> _onResetWizard(
    ResetWizardEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    emit(const WizardInitial());
  }
}
