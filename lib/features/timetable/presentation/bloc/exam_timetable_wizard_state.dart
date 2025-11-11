import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_calendar_entity.dart';
import '../../domain/entities/exam_timetable_entry_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';

/// Base state for exam timetable wizard
abstract class ExamTimetableWizardState extends Equatable {
  const ExamTimetableWizardState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class WizardInitial extends ExamTimetableWizardState {
  const WizardInitial();

  @override
  List<Object?> get props => [];
}

/// Step 1: Select exam calendar
class WizardStep1State extends ExamTimetableWizardState {
  final List<ExamCalendarEntity> calendars;
  final ExamCalendarEntity? selectedCalendar;
  final bool isLoading;
  final String? error;

  const WizardStep1State({
    this.calendars = const [],
    this.selectedCalendar,
    this.isLoading = false,
    this.error,
  });

  WizardStep1State copyWith({
    List<ExamCalendarEntity>? calendars,
    ExamCalendarEntity? selectedCalendar,
    bool? isLoading,
    String? error,
  }) {
    return WizardStep1State(
      calendars: calendars ?? this.calendars,
      selectedCalendar: selectedCalendar ?? this.selectedCalendar,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [calendars, selectedCalendar, isLoading, error];
}

/// Step 2: Select grades
class WizardStep2State extends ExamTimetableWizardState {
  final String tenantId;
  final ExamCalendarEntity selectedCalendar;
  final List<GradeEntity> availableGrades;
  final List<String> selectedGradeIds;
  final bool isLoading;
  final String? error;

  const WizardStep2State({
    required this.tenantId,
    required this.selectedCalendar,
    this.availableGrades = const [],
    this.selectedGradeIds = const [],
    this.isLoading = false,
    this.error,
  });

  WizardStep2State copyWith({
    String? tenantId,
    ExamCalendarEntity? selectedCalendar,
    List<GradeEntity>? availableGrades,
    List<String>? selectedGradeIds,
    bool? isLoading,
    String? error,
  }) {
    return WizardStep2State(
      tenantId: tenantId ?? this.tenantId,
      selectedCalendar: selectedCalendar ?? this.selectedCalendar,
      availableGrades: availableGrades ?? this.availableGrades,
      selectedGradeIds: selectedGradeIds ?? this.selectedGradeIds,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool isGradeSelected(String gradeId) => selectedGradeIds.contains(gradeId);

  @override
  List<Object?> get props => [
    tenantId,
    selectedCalendar,
    availableGrades,
    selectedGradeIds,
    isLoading,
    error,
  ];
}

/// Step 3: Assign subjects to dates
class WizardStep3State extends ExamTimetableWizardState {
  final String tenantId;
  final ExamCalendarEntity selectedCalendar;
  final List<String> selectedGradeIds;
  final List<SubjectEntity> subjects;
  final List<ExamTimetableEntryEntity> entries;
  final Map<String, String> gradeSectionMapping; // Maps gradeId -> gradeSectionId
  final bool isLoading;
  final String? error;

  const WizardStep3State({
    required this.tenantId,
    required this.selectedCalendar,
    required this.selectedGradeIds,
    this.subjects = const [],
    this.entries = const [],
    this.gradeSectionMapping = const {},
    this.isLoading = false,
    this.error,
  });

  WizardStep3State copyWith({
    String? tenantId,
    ExamCalendarEntity? selectedCalendar,
    List<String>? selectedGradeIds,
    List<SubjectEntity>? subjects,
    List<ExamTimetableEntryEntity>? entries,
    Map<String, String>? gradeSectionMapping,
    bool? isLoading,
    String? error,
  }) {
    return WizardStep3State(
      tenantId: tenantId ?? this.tenantId,
      selectedCalendar: selectedCalendar ?? this.selectedCalendar,
      selectedGradeIds: selectedGradeIds ?? this.selectedGradeIds,
      subjects: subjects ?? this.subjects,
      entries: entries ?? this.entries,
      gradeSectionMapping: gradeSectionMapping ?? this.gradeSectionMapping,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get assigned entry for a subject
  ExamTimetableEntryEntity? getEntryForSubject(String subjectId) {
    try {
      return entries.firstWhere((entry) => entry.subjectId == subjectId);
    } catch (e) {
      return null;
    }
  }

  /// Check if all subjects are assigned
  bool allSubjectsAssigned() => entries.length == subjects.length;

  /// Get unassigned subjects
  List<SubjectEntity> getUnassignedSubjects() {
    final assignedSubjectIds = entries.map((e) => e.subjectId).toSet();
    return subjects
        .where((subject) => !assignedSubjectIds.contains(subject.id))
        .toList();
  }

  @override
  List<Object?> get props => [
    tenantId,
    selectedCalendar,
    selectedGradeIds,
    subjects,
    entries,
    gradeSectionMapping,
    isLoading,
    error,
  ];
}

/// Wizard completed successfully
class WizardCompletedState extends ExamTimetableWizardState {
  final String timetableId;
  final String examName;
  final String message;

  const WizardCompletedState({
    required this.timetableId,
    required this.examName,
    required this.message,
  });

  @override
  List<Object?> get props => [timetableId, examName, message];
}

/// Wizard error state
class WizardErrorState extends ExamTimetableWizardState {
  final String message;
  final String? stackTrace;

  const WizardErrorState({
    required this.message,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, stackTrace];
}

/// Validation error in current step
class WizardValidationErrorState extends ExamTimetableWizardState {
  final List<String> errors;
  final String step;

  const WizardValidationErrorState({
    required this.errors,
    required this.step,
  });

  @override
  List<Object?> get props => [errors, step];
}
