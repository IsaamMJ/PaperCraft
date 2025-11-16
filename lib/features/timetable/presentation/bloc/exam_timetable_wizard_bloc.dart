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

/// BLoC for managing the 2-step exam timetable wizard
/// Step 1: Select exam calendar (automatically filters grades from calendar's marks config)
/// Step 2: Assign subjects to exam dates
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

  /// Step 1 → Step 2: Transition to loading and automatically selecting grades
  /// (Grades are automatically selected from calendar's marks config)
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
    } else if (currentState is WizardStep2State) {
      tenantId = currentState.tenantId;
    }

    print('[WizardBloc] TenantId: $tenantId');

    // Emit loading state to show spinner in UI
    emit(WizardStep2State(
      tenantId: tenantId,
      selectedCalendar: event.calendar,
      selectedGradeIds: const [],
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
        emit(WizardErrorState(message: 'Failed to load grades: $failure'));
      },
      (allGrades) async {
        print('[WizardBloc] SUCCESS: Loaded ${allGrades.length} grades');
        print('[WizardBloc] Filtering grades based on calendar marks config...');

        // Filter grades based on exam calendar's selected grades
        List<GradeEntity> availableGrades = allGrades;
        final selectedGradesFromCalendar = ExamCalendarEntity.getSelectedGradesFromMarksConfig(
          event.calendar.marksConfig,
        );

        if (selectedGradesFromCalendar != null && selectedGradesFromCalendar.isNotEmpty) {
          print('[WizardBloc] 📚 Filtering grades: selected from calendar = $selectedGradesFromCalendar');
          availableGrades = allGrades.where((grade) {
            return selectedGradesFromCalendar.contains(grade.gradeNumber);
          }).toList();
          print('[WizardBloc] ✅ Filtered to ${availableGrades.length} grades');
        }

        // Automatically select all filtered grades (since they come from calendar)
        final selectedGradeIds = availableGrades.map((g) => g.id).toList();
        print('[WizardBloc] 🔄 Automatically selecting ${selectedGradeIds.length} filtered grades');

        // Process selected grades (expand to sections and move to step 3)
        await _processSelectedGradesAndTransitionToStep3(
          tenantId: tenantId,
          calendar: event.calendar,
          selectedGradeIds: selectedGradeIds,
          availableGrades: availableGrades,
          emit: emit,
        );
      },
    );
  }

  /// Helper method to process selected grades and transition directly to step 2
  /// This skips the grade selection UI since grades are auto-selected from calendar
  Future<void> _processSelectedGradesAndTransitionToStep3({
    required String tenantId,
    required ExamCalendarEntity calendar,
    required List<String> selectedGradeIds,
    required List<GradeEntity> availableGrades,
    required Emitter<ExamTimetableWizardState> emit,
  }) async {
    print('[WizardBloc] Processing ${selectedGradeIds.length} selected grades...');

    // Expand selected grades to sections (same logic as _onSelectGrades)
    final List<String> allSectionIds = [];
    final gradeSectionMapping = <String, List<String>>{};
    final sectionDetailsMap = <String, Map<String, String>>{};
    final Map<String, int> gradeIdToGradeNumberMap = {};

    // Build the grade ID to grade number mapping from available grades
    print('[WizardBloc] Building grade ID to grade number mapping from ${availableGrades.length} available grades');
    for (final grade in availableGrades) {
      gradeIdToGradeNumberMap[grade.id] = grade.gradeNumber;
      print('[WizardBloc] Grade mapping: ${grade.id} → grade_number: ${grade.gradeNumber}');
    }

    for (final gradeId in selectedGradeIds) {
      print('[WizardBloc] Loading sections for grade: $gradeId');

      final sectionsResult = await loadGradeSections(
        tenantId: tenantId,
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
            return;
          }

          gradeSectionMapping[gradeId] = sections.map((s) => s.id).toList();

          for (final section in sections) {
            sectionDetailsMap[section.id] = {
              'gradeId': gradeId,
              'sectionName': section.sectionName,
            };
            allSectionIds.add(section.id);
            print('[WizardBloc] Added section: ${section.sectionName} (${section.id})');
          }
        },
      );
    }

    print('[WizardBloc] Expanded to ${allSectionIds.length} section IDs');

    if (allSectionIds.isEmpty) {
      emit(WizardErrorState(
        message: 'No sections found for selected grades. Please configure sections in settings.',
      ));
      return;
    }

    // Check if grades are already mapped for this calendar
    print('[WizardBloc] Checking if grades are already mapped for this calendar...');
    final alreadyMappedResult = await getGradesForCalendar(
      GetGradesForCalendarParams(examCalendarId: calendar.id),
    );

    print('[WizardBloc] Already mapped check: ${alreadyMappedResult.isRight() ? 'SUCCESS' : 'NOT FOUND'}');

    // If grades are already mapped, skip the mapping step and go directly to subjects
    final gradesAlreadyMapped = alreadyMappedResult.fold(
      (failure) => false,
      (alreadyMappedIds) {
        print('[WizardBloc] Grades already mapped (${alreadyMappedIds.length} found), skipping mapping step');
        return true;
      },
    );

    if (gradesAlreadyMapped) {
      // Load subjects for the sections
      print('[WizardBloc] Loading subjects for ${allSectionIds.length} sections...');
      await _loadSubjectsAndTransitionToStep2(
        tenantId: tenantId,
        calendar: calendar,
        selectedGradeIds: selectedGradeIds,
        gradeSectionMapping: gradeSectionMapping,
        sectionDetailsMap: sectionDetailsMap,
        gradeIdToGradeNumberMap: gradeIdToGradeNumberMap,
        emit: emit,
      );
      return;
    }

    // Map grades to calendar only if not already mapped
    print('[WizardBloc] Mapping ${allSectionIds.length} section IDs to calendar...');
    final mapResult = await mapGradesToExamCalendar(
      MapGradesToExamCalendarParams(
        tenantId: tenantId,
        examCalendarId: calendar.id,
        gradeSectionIds: allSectionIds,
      ),
    );

    print('[WizardBloc] Map result: ${mapResult.isRight() ? 'SUCCESS' : 'FAILURE'}');

    mapResult.fold(
      (failure) {
        print('[WizardBloc] FAILURE mapping grades: $failure');
        emit(WizardErrorState(message: 'Failed to map grades: $failure'));
      },
      (mappedResults) async {
        print('[WizardBloc] Successfully mapped ${mappedResults.length} grades');

        // Load subjects for the sections
        print('[WizardBloc] Loading subjects for ${allSectionIds.length} sections...');
        await _loadSubjectsAndTransitionToStep2(
          tenantId: tenantId,
          calendar: calendar,
          selectedGradeIds: selectedGradeIds,
          gradeSectionMapping: gradeSectionMapping,
          sectionDetailsMap: sectionDetailsMap,
          gradeIdToGradeNumberMap: gradeIdToGradeNumberMap,
          emit: emit,
        );
      },
    );
  }

  /// Load subjects and transition to step 2
  Future<void> _loadSubjectsAndTransitionToStep2({
    required String tenantId,
    required ExamCalendarEntity calendar,
    required List<String> selectedGradeIds,
    required Map<String, List<String>> gradeSectionMapping,
    required Map<String, Map<String, String>> sectionDetailsMap,
    required Map<String, int> gradeIdToGradeNumberMap,
    required Emitter<ExamTimetableWizardState> emit,
  }) async {
    // Load subjects per grade+section (same logic as _onSelectGrades)
    print('[WizardBloc] Loading subjects for ${gradeSectionMapping.length} grades...');
    final Map<String, SubjectEntity> subjectMap = <String, SubjectEntity>{};
    final Map<String, List<String>> subjectToGradesMap = <String, List<String>>{};

    for (final sectionId in sectionDetailsMap.keys) {
      final details = sectionDetailsMap[sectionId];
      final gradeId = details?['gradeId'];
      final sectionName = details?['sectionName'];

      if (gradeId != null && sectionName != null) {
        print('[WizardBloc] Loading subjects for grade=$gradeId, section=$sectionName');
        final subjectsResult = await getSubjectsByGradeAndSection(
          tenantId,
          gradeId,
          sectionName,
        );

        await subjectsResult.fold(
          (failure) async {
            print('[WizardBloc] WARNING: Failed to load subjects for grade $gradeId, section $sectionName: $failure');
          },
          (subjects) {
            print('[WizardBloc] Loaded ${subjects.length} subjects for grade $gradeId, section $sectionName');
            for (final subject in subjects) {
              subjectMap[subject.id] = subject;

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
    print('[WizardBloc] Loaded ${uniqueSubjects.length} unique subjects');
    print('[WizardBloc] Emitting WizardStep2State to move to schedule step');

    emit(WizardStep2State(
      tenantId: tenantId,
      selectedCalendar: calendar,
      selectedGradeIds: selectedGradeIds,
      subjects: uniqueSubjects,
      gradeSectionMapping: gradeSectionMapping,
      sectionDetailsMap: sectionDetailsMap,
      subjectToGradesMap: subjectToGradesMap,
      gradeIdToNumberMap: gradeIdToGradeNumberMap,
      isLoading: false,
    ));
  }


  /// Step 3: Assign a subject to an exam date
  Future<void> _onAssignSubjectDate(
    AssignSubjectDateEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep2State) return;
    final step3State = state as WizardStep2State;

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
    if (state is! WizardStep2State) return;
    final step3State = state as WizardStep2State;

    final updatedEntries =
        step3State.entries.where((e) => e.subjectId != event.subjectId).toList();

    emit(step3State.copyWith(entries: updatedEntries));
  }

  /// Step 3: Update a subject assignment
  Future<void> _onUpdateSubjectAssignment(
    UpdateSubjectAssignmentEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep2State) return;

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
    if (state is! WizardStep2State) return;
    final step3State = state as WizardStep2State;

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

  /// Go back to previous step
  Future<void> _onGoBack(
    GoBackEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    final currentState = state;

    if (currentState is WizardStep2State) {
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
