import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../assignments/domain/repositories/teacher_subject_repository.dart';
import '../../../exams/domain/entities/exam_timetable_entry.dart';
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
import '../../../catalog/domain/usecases/get_subjects_usecase.dart'
    show GetSubjectsByGradeAndSectionUseCase;
import '../../domain/services/exam_timetable_grouping_service.dart';
import '../../../paper_workflow/domain/usecases/auto_assign_question_papers_usecase.dart';
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
  final TeacherSubjectRepository teacherSubjectRepository;
  final AutoAssignQuestionPapersUsecase autoAssignQuestionPapers;

  late String _currentUserId;
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
    required this.teacherSubjectRepository,
    required this.autoAssignQuestionPapers,
  }) : super(const WizardInitial()) {
    on<InitializeWizardEvent>(_onInitializeWizard);
    on<SelectExamCalendarEvent>(_onSelectExamCalendar);
    on<AssignSubjectDateEvent>(_onAssignSubjectDate);
    on<RemoveSubjectAssignmentEvent>(_onRemoveSubjectAssignment);
    on<UpdateSubjectAssignmentEvent>(_onUpdateSubjectAssignment);
    on<BatchAssignSubjectsEvent>(_onBatchAssignSubjects);
    on<GoToNextStepEvent>(_onGoToNextStep);
    on<LoadTeacherAssignmentsEvent>(_onLoadTeacherAssignments);
    on<SubmitWizardEvent>(_onSubmitWizard);
    on<GoBackEvent>(_onGoBack);
    on<ResetWizardEvent>(_onResetWizard);
  }

  Future<void> _onInitializeWizard(
      InitializeWizardEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
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

  Future<void> _onSelectExamCalendar(
      SelectExamCalendarEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    final currentState = state;
    String tenantId = '';

    if (currentState is WizardStep1State) {
      tenantId = event.calendar.tenantId;
    } else if (currentState is WizardStep2State) {
      tenantId = currentState.tenantId;
    } else if (currentState is WizardStep3State) {
      tenantId = currentState.tenantId;
    }

    emit(WizardStep2State(
      tenantId: tenantId,
      selectedCalendar: event.calendar,
      selectedGradeIds: const [],
      isLoading: true,
    ));

    final gradesResult = await getGrades();

    await gradesResult.fold(
          (failure) async {
        emit(WizardErrorState(message: 'Failed to load grades: $failure'));
      },
          (allGrades) async {
        List<GradeEntity> availableGrades = allGrades;

        if (event.calendar.selectedGradeNumbers != null &&
            event.calendar.selectedGradeNumbers!.isNotEmpty) {
          availableGrades = allGrades.where((grade) {
            return event.calendar.selectedGradeNumbers!
                .contains(grade.gradeNumber);
          }).toList();
        } else {
          emit(WizardErrorState(
            message:
            'Exam calendar "${event.calendar.examName}" does not have grades configured. '
                'Please edit the calendar and select which grades will participate in this exam.',
          ));
          return;
        }

        final selectedGradeIds = availableGrades.map((g) => g.id).toList();

        await _processSelectedGradesAndTransitionToStep2(
          tenantId: tenantId,
          calendar: event.calendar,
          selectedGradeIds: selectedGradeIds,
          availableGrades: availableGrades,
          emit: emit,
        );
      },
    );
  }

  Future<void> _processSelectedGradesAndTransitionToStep2({
    required String tenantId,
    required ExamCalendarEntity calendar,
    required List<String> selectedGradeIds,
    required List<GradeEntity> availableGrades,
    required Emitter<ExamTimetableWizardState> emit,
  }) async {
    final List<String> allSectionIds = [];
    final gradeSectionMapping = <String, List<String>>{};
    final sectionDetailsMap = <String, Map<String, String>>{};
    final Map<String, int> gradeIdToGradeNumberMap = {};

    for (final grade in availableGrades) {
      gradeIdToGradeNumberMap[grade.id] = grade.gradeNumber;
    }

    for (final gradeId in selectedGradeIds) {
      final sectionsResult = await loadGradeSections(
        tenantId: tenantId,
        gradeId: gradeId,
      );

      sectionsResult.fold(
            (failure) {},
            (sections) {
          if (sections.isEmpty) {
            return;
          }

          gradeSectionMapping[gradeId] = sections.map((s) => s.id).toList();

          for (final section in sections) {
            sectionDetailsMap[section.id] = {
              'gradeId': gradeId,
              'sectionName': section.sectionName,
            };
            allSectionIds.add(section.id);
          }
        },
      );
    }

    if (allSectionIds.isEmpty) {
      emit(WizardErrorState(
        message:
        'No sections found for selected grades. Please configure sections in settings.',
      ));
      return;
    }

    final alreadyMappedResult = await getGradesForCalendar(
      GetGradesForCalendarParams(examCalendarId: calendar.id),
    );

    final gradesAlreadyMapped = alreadyMappedResult.fold(
          (failure) => false,
          (alreadyMappedIds) => true,
    );

    if (gradesAlreadyMapped) {
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

    final mapResult = await mapGradesToExamCalendar(
      MapGradesToExamCalendarParams(
        tenantId: tenantId,
        examCalendarId: calendar.id,
        gradeSectionIds: allSectionIds,
      ),
    );

    mapResult.fold(
          (failure) {
        emit(WizardErrorState(message: 'Failed to map grades: $failure'));
      },
          (mappedResults) async {
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

  Future<void> _loadSubjectsAndTransitionToStep2({
    required String tenantId,
    required ExamCalendarEntity calendar,
    required List<String> selectedGradeIds,
    required Map<String, List<String>> gradeSectionMapping,
    required Map<String, Map<String, String>> sectionDetailsMap,
    required Map<String, int> gradeIdToGradeNumberMap,
    required Emitter<ExamTimetableWizardState> emit,
  }) async {
    final Map<String, SubjectEntity> subjectMap = <String, SubjectEntity>{};
    final Map<String, List<String>> subjectToGradesMap =
    <String, List<String>>{};

    for (final sectionId in sectionDetailsMap.keys) {
      final details = sectionDetailsMap[sectionId];
      final gradeId = details?['gradeId'];
      final sectionName = details?['sectionName'];

      if (gradeId != null && sectionName != null) {
        final subjectsResult = await getSubjectsByGradeAndSection(
          tenantId,
          gradeId,
          sectionName,
        );

        await subjectsResult.fold(
              (failure) async {},
              (subjects) {
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

  Future<void> _onAssignSubjectDate(
      AssignSubjectDateEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;


    if (event.examDate.isBefore(step2State.selectedCalendar.plannedStartDate) ||
        event.examDate.isAfter(step2State.selectedCalendar.plannedEndDate)) {
      emit(WizardValidationErrorState(
        errors: [
          'Exam date must be between ${step2State.selectedCalendar.plannedStartDate.toLocal()} '
              'and ${step2State.selectedCalendar.plannedEndDate.toLocal()}'
        ],
        step: 'step_2',
      ));
      return;
    }

    final startMinutes = event.startTime.hour * 60 + event.startTime.minute;
    final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      emit(WizardValidationErrorState(
        errors: ['End time must be after start time'],
        step: 'step_2',
      ));
      return;
    }

    // Validate the specific grade
    final sections = step2State.gradeSectionMapping[event.gradeId];
    if (sections == null || sections.isEmpty) {
      emit(WizardValidationErrorState(
        errors: [
          'No sections found for grade ${step2State.gradeIdToNumberMap[event.gradeId] ?? event.gradeId}'
        ],
        step: 'step_2',
      ));
      return;
    }

    // Create entries only for this specific grade's sections
    final List<ExamTimetableEntry> newEntries = [];
    final gradeSectionIds = sections as List<dynamic>;

    for (final gradeSectionId in gradeSectionIds) {

      final sectionDetails =
      step2State.sectionDetailsMap[gradeSectionId] as Map<String, dynamic>?;
      final gradeId = sectionDetails?['gradeId'] as String? ?? '';
      final sectionName = sectionDetails?['sectionName'] as String? ?? '';


      final newEntry = ExamTimetableEntry(
        id: const Uuid().v4(), // Generate unique ID for this entry
        tenantId: step2State.tenantId,
        timetableId: '',
        gradeId: gradeId,
        subjectId: event.subjectId,
        section: sectionName,
        gradeSectionId: gradeSectionId, // Store FK reference to grade_sections
        examDate: event.examDate,
        startTime: event.startTime,
        endTime: event.endTime,
        durationMinutes: durationMinutes,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      newEntries.add(newEntry);
    }

    // FIX: Only remove entries for THIS GRADE + SUBJECT combo, not all subjects!
    final updatedEntries = step2State.entries
        .where((e) => !(e.subjectId == event.subjectId && e.gradeId == event.gradeId))
        .toList();
    updatedEntries.addAll(newEntries);


    emit(step2State.copyWith(entries: updatedEntries));
  }

  Future<void> _onBatchAssignSubjects(
      BatchAssignSubjectsEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;

    // Validate date
    if (event.examDate.isBefore(step2State.selectedCalendar.plannedStartDate) ||
        event.examDate.isAfter(step2State.selectedCalendar.plannedEndDate)) {
      emit(WizardValidationErrorState(
        errors: [
          'Exam date must be between ${step2State.selectedCalendar.plannedStartDate.toLocal()} '
              'and ${step2State.selectedCalendar.plannedEndDate.toLocal()}'
        ],
        step: 'step_2',
      ));
      return;
    }

    // Validate time range
    final startMinutes = event.startTime.hour * 60 + event.startTime.minute;
    final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      emit(WizardValidationErrorState(
        errors: ['End time must be after start time'],
        step: 'step_2',
      ));
      return;
    }

    // Batch assign each subject to all its grades
    var updatedEntries = step2State.entries.toList();

    for (final subjectId in event.subjectIds) {
      final gradesWithSubject = step2State.subjectToGradesMap[subjectId] ?? [];
      final List<ExamTimetableEntry> newSubjectEntries = [];

      for (final gradeId in gradesWithSubject) {
        final sections = step2State.gradeSectionMapping[gradeId] as List<dynamic>? ?? [];

        for (final gradeSectionId in sections) {
          final sectionDetails =
          step2State.sectionDetailsMap[gradeSectionId] as Map<String, dynamic>?;
          final sectionName = sectionDetails?['sectionName'] as String? ?? '';

          final newEntry = ExamTimetableEntry(
            id: const Uuid().v4(), // Generate unique ID for this entry
            tenantId: step2State.tenantId,
            timetableId: '',
            gradeId: gradeId,
            subjectId: subjectId,
            section: sectionName,
            gradeSectionId: gradeSectionId, // Store FK reference to grade_sections
            examDate: event.examDate,
            startTime: event.startTime,
            endTime: event.endTime,
            durationMinutes: durationMinutes,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          newSubjectEntries.add(newEntry);
        }
      }

      // Remove existing entries for this subject and add new ones
      updatedEntries = updatedEntries
          .where((e) => e.subjectId != subjectId)
          .toList();
      updatedEntries.addAll(newSubjectEntries);
    }

    emit(step2State.copyWith(entries: updatedEntries));
  }

  Future<void> _onRemoveSubjectAssignment(
      RemoveSubjectAssignmentEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;

    final updatedEntries =
    step2State.entries.where((e) => e.subjectId != event.subjectId).toList();

    emit(step2State.copyWith(entries: updatedEntries));
  }

  Future<void> _onUpdateSubjectAssignment(
      UpdateSubjectAssignmentEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    if (state is! WizardStep2State) return;

    add(RemoveSubjectAssignmentEvent(subjectId: event.subjectId));
    add(AssignSubjectDateEvent(
      subjectId: event.subjectId,
      gradeId: event.gradeId,
      examDate: event.newExamDate,
      startTime: event.newStartTime,
      endTime: event.newEndTime,
    ));
  }

  Future<void> _onGoToNextStep(
      GoToNextStepEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    final currentState = state;


    if (currentState is WizardStep2State) {

      if (currentState.entries.isEmpty) {
        emit(WizardValidationErrorState(
          errors: [
            'Please assign at least one subject a date before proceeding'
          ],
          step: 'step_2',
        ));
        return;
      }

      for (var entry in currentState.entries) {
      }

      emit(WizardStep3State(
        tenantId: currentState.tenantId,
        selectedCalendar: currentState.selectedCalendar,
        selectedGradeIds: currentState.selectedGradeIds,
        subjects: currentState.subjects,
        entries: currentState.entries,
        gradeSectionMapping: currentState.gradeSectionMapping,
        sectionDetailsMap: currentState.sectionDetailsMap,
        subjectToGradesMap: currentState.subjectToGradesMap,
        gradeIdToNumberMap: currentState.gradeIdToNumberMap,
        isLoading: false,
      ));
    }
  }

  /// Step 3: Load teacher assignments for all scheduled subjects
  Future<void> _onLoadTeacherAssignments(
      LoadTeacherAssignmentsEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    final currentState = state;


    if (currentState is! WizardStep3State) {
      return;
    }

    final step3 = currentState as WizardStep3State;

    emit(currentState.copyWith(isLoading: true));

    try {
      final Map<String, List<String>> entryTeachers = {};
      final Map<String, String> entryTeacherNames = {};

      for (final entry in step3.entries) {
        final key = '${entry.gradeId}_${entry.subjectId}_${entry.section}';

        final teachersResult = await teacherSubjectRepository.getTeachersFor(
          tenantId: step3.tenantId,
          gradeId: entry.gradeId,
          subjectId: entry.subjectId,
          section: entry.section,
          academicYear: event.academicYear,
          activeOnly: true,
        );

        await teachersResult.fold(
              (failure) {
            entryTeacherNames[key] = 'No teacher assigned';
          },
              (teacherSubjects) {
            if (teacherSubjects.isEmpty) {
              entryTeacherNames[key] = 'No teacher assigned';
            } else {
              // Use teacher names if available, otherwise fall back to teacherId
              final teacherNames = teacherSubjects
                  .map((ts) => ts.teacherName ?? ts.teacherId)
                  .toList();
              entryTeacherNames[key] = teacherNames.join(', ');

              // Also store teacher IDs for reference
              final teacherIds = teacherSubjects
                  .map((ts) => ts.teacherId)
                  .toList();
              entryTeachers[key] = teacherIds;
            }
          },
        );
      }


      emit(currentState.copyWith(
        isLoading: false,
        entryTeachers: entryTeachers,
        entryTeacherNames: entryTeacherNames,
        error: null,
      ));
    } catch (e, st) {
      emit(currentState.copyWith(
        isLoading: false,
        error: 'Failed to load teacher assignments: ${e.toString()}',
      ));
    }
  }

  /// Convert ExamTimetableEntry (presentation) to ExamTimetableEntryEntity (domain)
  /// Also looks up subject_type and max_marks from subject_catalog and exam_calendar
  ExamTimetableEntryEntity _convertToDomainEntity(
    ExamTimetableEntry entry,
    ExamCalendarEntity calendar,
    List<SubjectEntity> subjects,
  ) {
    // Find the subject to get its type
    final subject = subjects.firstWhere(
      (s) => s.id == entry.subjectId,
      orElse: () => SubjectEntity(
        id: entry.subjectId,
        tenantId: entry.tenantId,
        catalogSubjectId: entry.subjectId,
        name: 'Unknown',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );

    // Determine max marks based on subject type and exam calendar
    // Extract marks from exam_calendar metadata or use defaults
    // Default: Core subjects = 60 marks, Auxiliary subjects = 50 marks
    final subjectType = 'core'; // TODO: Get actual subjectType from subject_catalog if available

    int maxMarks = 60; // Default for core
    if (calendar.metadata != null) {
      if (subjectType == 'core' && calendar.metadata!['core_max_marks'] != null) {
        maxMarks = calendar.metadata!['core_max_marks'] as int;
      } else if (subjectType == 'auxiliary' && calendar.metadata!['auxiliary_max_marks'] != null) {
        maxMarks = calendar.metadata!['auxiliary_max_marks'] as int;
      } else if (subjectType == 'auxiliary') {
        maxMarks = 50; // Default for auxiliary
      }
    } else if (subjectType == 'auxiliary') {
      maxMarks = 50;
    }


    final convertedEntity = ExamTimetableEntryEntity(
      id: entry.id,
      tenantId: entry.tenantId,
      timetableId: entry.timetableId,
      gradeSectionId: entry.gradeSectionId, // Use actual gradeSectionId FK
      gradeId: entry.gradeId,
      subjectId: entry.subjectId,
      section: entry.section,
      examDate: entry.examDate,
      startTime: Duration(
        hours: entry.startTime.hour,
        minutes: entry.startTime.minute,
      ),
      endTime: Duration(
        hours: entry.endTime.hour,
        minutes: entry.endTime.minute,
      ),
      durationMinutes: entry.durationMinutes,
      subjectType: subjectType,
      maxMarks: maxMarks,
      isActive: entry.isActive,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );

    return convertedEntity;
  }

  Future<void> _onSubmitWizard(
      SubmitWizardEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    final currentState = state;


    if (currentState is WizardStep3State) {
      emit(currentState.copyWith(isLoading: true, error: null));


      // Group entries by (gradeId, subjectId, teacher) and combine sections
      final groupedEntries = ExamTimetableGroupingService.groupEntriesBySubjectAndTeacher(
        currentState.entries,
        currentState.entryTeacherNames,
      );

      for (var entry in groupedEntries) {
      }

      // Convert entries from presentation model to domain entity
      final domainEntries = groupedEntries
          .map((entry) => _convertToDomainEntity(
            entry,
            currentState.selectedCalendar,
            currentState.subjects,
          ))
          .toList();

      for (var entry in domainEntries) {
      }


      final result = await createExamTimetableWithEntries(
        CreateExamTimetableWithEntriesParams(
          tenantId: currentState.tenantId,
          examCalendarId: currentState.selectedCalendar.id,
          examName: currentState.selectedCalendar.examName,
          examType: currentState.selectedCalendar.examType,
          academicYear: _currentAcademicYear,
          createdByUserId: _currentUserId,
          entries: domainEntries,
        ),
      );


      result.fold(
            (failure) {
          emit(currentState.copyWith(
            isLoading: false,
            error: failure.toString(),
          ));
        },
            (timetable) {

          // Timetable and entries created in DRAFT status
          // Papers will be created when user clicks "Publish Timetable"

          emit(WizardCompletedState(
            timetableId: timetable.id,
            examName: timetable.examName,
            message: 'Exam timetable created successfully (DRAFT)!\n${currentState.entries.length} exam entries scheduled.\n\nNext: Click "Publish Timetable" to publish the timetable and create question papers as draft.',
          ));
        },
      );
    } else {
    }
  }

  Future<void> _onGoBack(
      GoBackEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    final currentState = state;

    if (currentState is WizardStep3State) {
      emit(WizardStep2State(
        tenantId: currentState.tenantId,
        selectedCalendar: currentState.selectedCalendar,
        selectedGradeIds: currentState.selectedGradeIds,
        subjects: currentState.subjects,
        entries: currentState.entries,
        gradeSectionMapping: currentState.gradeSectionMapping,
        sectionDetailsMap: currentState.sectionDetailsMap,
        subjectToGradesMap: currentState.subjectToGradesMap,
        gradeIdToNumberMap: currentState.gradeIdToNumberMap,
      ));
    } else if (currentState is WizardStep2State) {
      emit(WizardStep1State(
        selectedCalendar: currentState.selectedCalendar,
      ));
    }
  }

  Future<void> _onResetWizard(
      ResetWizardEvent event,
      Emitter<ExamTimetableWizardState> emit,
      ) async {
    emit(const WizardInitial());
  }
}