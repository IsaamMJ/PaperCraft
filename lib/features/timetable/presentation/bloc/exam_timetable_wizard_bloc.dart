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
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/usecases/get_subjects_usecase.dart' show GetSubjectsByGradeAndSectionUseCase;
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
  final GetSubjectsByGradeUseCase getSubjectsByGrade;
  final GetSubjectsByGradeAndSectionUseCase getSubjectsByGradeAndSection;
  final LoadGradeSectionsUseCase loadGradeSections;

  /// Store the current user ID
  late String _currentUserId;

  /// Store the academic year for the timetable
  late String _currentAcademicYear;

  ExamTimetableWizardBloc({
    required this.getExamCalendars,
    required this.mapGradesToExamCalendar,
    required this.getGradesForCalendar,
    required this.createExamTimetableWithEntries,
    required this.getGrades,
    required this.getSubjects,
    required this.getSubjectsByGrade,
    required this.getSubjectsByGradeAndSection,
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
    // Store the user ID and academic year for later use in submission
    _currentUserId = event.userId;
    _currentAcademicYear = event.academicYear;

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
    // IMPORTANT: We need SECTION IDs (from grade_sections table), not grade IDs!
    final List<String> allSectionIds = [];
    final gradeSectionMapping = <String, List<String>>{};
    final sectionDetailsMap = <String, Map<String, String>>{}; // sectionId -> {gradeId, sectionName}
    final Map<String, int> gradeIdToGradeNumberMap = {}; // gradeId -> grade_number

    // Build grade ID to grade number mapping from available grades in state
    print('[WizardBloc] Building grade ID to grade number mapping from ${step2State.availableGrades.length} available grades');
    for (final grade in step2State.availableGrades) {
      gradeIdToGradeNumberMap[grade.id] = grade.gradeNumber;
      print('[WizardBloc] Grade mapping: ${grade.id} -> grade_number: ${grade.gradeNumber}');
    }

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

          if (sections.isEmpty) {
            print('[WizardBloc] WARNING: Grade $gradeId has no sections configured');
          } else {
            // Add SECTION IDs (not grade IDs)
            final sectionIds = <String>[];
            for (final section in sections) {
              final sectionId = section.id; // This is the UUID from grade_sections table
              allSectionIds.add(sectionId);
              sectionIds.add(sectionId);

              // Store section details for later lookup
              sectionDetailsMap[sectionId] = {
                'gradeId': gradeId,
                'sectionName': section.sectionName,
              };
              print('[WizardBloc] Added section: ${section.sectionName} (ID: $sectionId) for grade $gradeId');
            }
            gradeSectionMapping[gradeId] = sectionIds;
          }
        },
      );
    }

    if (allSectionIds.isEmpty) {
      // No grades have sections
      emit(step2State.copyWith(
        isLoading: false,
        error: 'Selected grades have no sections configured. Please configure sections in the academic structure first.',
      ));
      return;
    }

    // Map all expanded grade sections to calendar
    print('[WizardBloc] Mapping ${allSectionIds.length} section(s) to calendar ${event.examCalendarId}');
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

        // Load subjects from grade_section_subject table for each grade+section combination
        // This is the source of truth for which subjects are actually available per grade/section
        print('[WizardBloc] Querying grade_section_subject table for ${sectionDetailsMap.length} sections...');
        final Map<String, SubjectEntity> subjectMap = <String, SubjectEntity>{}; // Deduplicate by subject ID
        final Map<String, List<String>> subjectToGradesMap = <String, List<String>>{}; // Track subject -> list of gradeIds

        // Iterate through each section and load its configured subjects
        for (final sectionId in sectionDetailsMap.keys) {
          final sectionDetails = sectionDetailsMap[sectionId] as Map<String, dynamic>? ?? {};
          final gradeId = sectionDetails['gradeId'] as String?;
          final sectionName = sectionDetails['sectionName'] as String?;

          if (gradeId != null && sectionName != null) {
            print('[WizardBloc] Loading subjects for grade=$gradeId, section=$sectionName');
            final subjectsResult = await getSubjectsByGradeAndSection(
              step2State.tenantId,
              gradeId,
              sectionName,
            );

            await subjectsResult.fold(
              (failure) async {
                print('[WizardBloc] WARNING: Failed to load subjects for grade $gradeId, section $sectionName: $failure');
                // Continue with other sections instead of failing completely
              },
              (subjects) {
                print('[WizardBloc] Loaded ${subjects.length} subjects for grade $gradeId, section $sectionName');
                // Add to map - keyed by subject ID to automatically deduplicate
                for (final subject in subjects) {
                  subjectMap[subject.id] = subject;

                  // Track which grades have this subject
                  if (!subjectToGradesMap.containsKey(subject.id)) {
                    subjectToGradesMap[subject.id] = [];
                  }
                  if (!subjectToGradesMap[subject.id]!.contains(gradeId)) {
                    subjectToGradesMap[subject.id]!.add(gradeId);
                  }
                }
              },
            );
          }
        }

        final uniqueSubjects = subjectMap.values.toList();
        print('[WizardBloc] Combined total: ${uniqueSubjects.length} unique subjects after deduplication (was ${subjectMap.length})');
        _emitStep3State(emit, step2State, event, uniqueSubjects, gradeSectionMapping, sectionDetailsMap, allSectionIds.length, subjectToGradesMap, gradeIdToGradeNumberMap);
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

    // Create ONE entry per subject that applies to ALL selected grades
    if (step3State.selectedGradeIds.isEmpty) {
      emit(WizardValidationErrorState(
        errors: ['No grades selected'],
        step: 'step_3',
      ));
      return;
    }

    // Validate that all grades have section mappings
    for (final gradeId in step3State.selectedGradeIds) {
      final sections = step3State.gradeSectionMapping[gradeId];
      if (sections == null || sections.isEmpty) {
        emit(WizardValidationErrorState(
          errors: ['Grade section mapping not found for grade $gradeId. Please go back and reselect grades.'],
          step: 'step_3',
        ));
        return;
      }
    }

    // Create ONE entry per subject that applies to ONLY the grades where the subject is available
    // The timetable tracks which grades it's for, so we create entries for each grade section
    final List<ExamTimetableEntryEntity> newEntries = [];

    // Get the grades that have this subject from the mapping
    final gradesWithSubject = step3State.subjectToGradesMap[event.subjectId] ?? [];
    print('[WizardBloc] Subject ${event.subjectId} is available in ${gradesWithSubject.length} grades: ${gradesWithSubject.join(", ")}');

    // Get all grade section IDs, but ONLY for grades that have this subject
    final allGradeSectionIds = <String>{};
    for (final gradeId in gradesWithSubject) {
      final gradeSectionIds = step3State.gradeSectionMapping[gradeId] as List<dynamic>? ?? [];
      allGradeSectionIds.addAll(gradeSectionIds.cast<String>());
    }

    print('[WizardBloc] Creating entries for ${allGradeSectionIds.length} grade sections that have this subject');

    // Create one entry per grade section with proper gradeId and section name
    for (final gradeSectionId in allGradeSectionIds) {
      // Look up section details from the map
      final sectionDetails = step3State.sectionDetailsMap[gradeSectionId] as Map<String, dynamic>?;
      final gradeId = sectionDetails?['gradeId'] as String? ?? '';
      final sectionName = sectionDetails?['sectionName'] as String? ?? '';

      final newEntry = ExamTimetableEntryEntity(
        id: null, // Let database generate UUID
        tenantId: step3State.tenantId,
        timetableId: '',
        gradeSectionId: gradeSectionId, // Real grade_section_id from database
        gradeId: gradeId, // Actual grade ID
        section: sectionName, // Actual section name (A, B, C, etc.)
        subjectId: event.subjectId,
        examDate: event.examDate,
        startTime: Duration(hours: event.startTime.hour, minutes: event.startTime.minute),
        endTime: Duration(hours: event.endTime.hour, minutes: event.endTime.minute),
        durationMinutes: durationMinutes,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      newEntries.add(newEntry);
    }

    print('[WizardBloc] Creating ${newEntries.length} entries (${allGradeSectionIds.length} sections across ${gradesWithSubject.length} grades that have this subject) for subject: ${event.subjectId}');

    // Remove existing entries for this subject and add new ones for all grade sections
    final updatedEntries = step3State.entries.where((e) => e.subjectId != event.subjectId).toList();
    updatedEntries.addAll(newEntries);

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
        academicYear: _currentAcademicYear, // Uses the academic year from initialization
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

  /// Helper method to emit Step3State
  void _emitStep3State(
    Emitter<ExamTimetableWizardState> emit,
    WizardStep2State step2State,
    SelectGradesEvent event,
    List<SubjectEntity> subjects,
    Map<String, List<String>> gradeSectionMapping,
    Map<String, Map<String, String>> sectionDetailsMap,
    int sectionCount,
    Map<String, List<String>> subjectToGradesMap,
    Map<String, int> gradeIdToGradeNumberMap,
  ) {
    print('[WizardBloc] Emitting WizardStep3State with ${subjects.length} subjects');
    print('[WizardBloc] Subject to grades mapping: ${subjectToGradesMap.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join(" | ")}');
    print('[WizardBloc] Grade ID to number mapping: ${gradeIdToGradeNumberMap.entries.map((e) => '${e.key}: grade ${e.value}').join(", ")}');
    emit(WizardStep3State(
      tenantId: step2State.tenantId,
      selectedCalendar: step2State.selectedCalendar,
      selectedGradeIds: event.gradeSectionIds, // Store original grade IDs for reference
      subjects: subjects,
      gradeSectionMapping: gradeSectionMapping,
      sectionDetailsMap: sectionDetailsMap,
      subjectToGradesMap: subjectToGradesMap, // Pass the mapping so UI can show correct grade availability
      gradeIdToNumberMap: gradeIdToGradeNumberMap, // Pass grade ID to number mapping
      isLoading: false,
    ));
    print('[WizardBloc] WizardStep3State emitted successfully with $sectionCount grade sections and ${subjects.length} subjects');
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
