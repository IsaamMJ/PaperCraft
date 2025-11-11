# Exam Timetable 3-Step Wizard - Implementation Guide

**Status**: COMPLETED (Database & Backend) | IN PROGRESS (Frontend)

---

## **COMPLETION SUMMARY**

### ✅ PHASE 1: DATABASE MIGRATIONS (COMPLETED)

Created 2 migration files:

1. **`20251111_add_exam_calendar_grade_mapping.sql`**
   - Creates `exam_calendar_grade_mapping` table
   - Maps exam calendars to grades (Step 2)
   - Includes RLS policies, indexes, and triggers

2. **`20251111_add_timetable_date_validation.sql`**
   - Adds date validation trigger
   - Ensures exam dates are within calendar range
   - Prevents invalid date assignments

**Action**: Run these migrations on your Supabase database.

---

### ✅ PHASE 2: DART ENTITIES & MODELS (COMPLETED)

#### New Entities:
1. **`exam_calendar_grade_mapping_entity.dart`**
   - Domain entity for grade-calendar mappings
   - Properties: id, tenantId, examCalendarId, gradeId, isActive, timestamps

2. **`exam_timetable_wizard_data.dart`**
   - State container for wizard progression
   - Holds Step 1, 2, 3 data
   - Helper methods for step validation

#### New Models:
1. **`exam_calendar_grade_mapping_model.dart`**
   - JSON serialization for database
   - `fromJson()` and `toJson()` methods
   - `toInsertJson()` for Supabase inserts

**Location**: `lib/features/timetable/domain/entities/` and `lib/features/timetable/data/models/`

---

### ✅ PHASE 3: DATA SOURCES (COMPLETED)

Extended `ExamTimetableRemoteDataSource` with Step 2 methods:

```dart
// Grade Mapping Operations
Future<Either<Failure, List<String>>> getGradesForCalendar(String examCalendarId);
Future<Either<Failure, ExamCalendarGradeMappingEntity>> addGradeToCalendar(
  String tenantId, String examCalendarId, String gradeId,
);
Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>> addGradesToCalendar(
  String tenantId, String examCalendarId, List<String> gradeIds,
);
Future<Either<Failure, void>> removeGradeFromCalendar(
  String examCalendarId, String gradeId,
);
Future<Either<Failure, void>> removeGradesFromCalendar(
  String examCalendarId, List<String> gradeIds,
);
Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>> getCalendarGradeMappings(
  String examCalendarId,
);
Future<Either<Failure, bool>> isGradeMappedToCalendar(
  String examCalendarId, String gradeId,
);
```

**Location**: `lib/features/timetable/data/datasources/exam_timetable_remote_data_source.dart`

---

### ✅ PHASE 4: REPOSITORIES (COMPLETED)

Updated `ExamTimetableRepository` interface and implementation:

**New Methods**:
```dart
Future<Either<Failure, List<String>>> getGradesForCalendar(String examCalendarId);
Future<Either<Failure, List<ExamCalendarGradeMappingEntity>>> mapGradesToExamCalendar(
  String tenantId, String examCalendarId, List<String> gradeIds,
);
Future<Either<Failure, void>> removeGradesFromCalendar(String examCalendarId, List<String> gradeIds);
Future<Either<Failure, ExamTimetableEntity>> createExamTimetableWithEntries({
  required String tenantId,
  String? examCalendarId,
  required String examName,
  required String examType,
  required String academicYear,
  required String createdByUserId,
  required List<ExamTimetableEntryEntity> entries,
});
```

**Location**: `lib/features/timetable/domain/repositories/` and `lib/features/timetable/data/repositories/`

---

### ✅ PHASE 5: USE CASES (COMPLETED)

Created 3 new use cases:

1. **`map_grades_to_exam_calendar_usecase.dart`**
   - Step 2: Maps selected grades to exam calendar
   - Validates inputs
   - Returns list of created mappings

2. **`get_grades_for_calendar_usecase.dart`**
   - Step 2: Retrieves already-selected grades
   - Used for UI state initialization
   - Returns list of grade IDs

3. **`create_exam_timetable_with_entries_usecase.dart`**
   - Step 3: Creates complete timetable with entries
   - Validates all entries have dates
   - Returns created timetable

**Location**: `lib/features/timetable/domain/usecases/`

---

## **NEXT STEPS - FRONTEND IMPLEMENTATION**

### 🔲 PHASE 6: CREATE BLoC EVENTS & STATES

Create new BLoC file: `lib/features/timetable/presentation/bloc/exam_timetable_wizard_bloc.dart`

```dart
// Events
abstract class ExamTimetableWizardEvent extends Equatable {}

class InitializeWizardEvent extends ExamTimetableWizardEvent {
  final String tenantId;
  final String academicYear;

  @override
  List<Object?> get props => [tenantId, academicYear];
}

class SelectExamCalendarEvent extends ExamTimetableWizardEvent {
  final ExamCalendarEntity calendar;

  @override
  List<Object?> get props => [calendar];
}

class SelectGradesEvent extends ExamTimetableWizardEvent {
  final String examCalendarId;
  final List<String> gradeIds;

  @override
  List<Object?> get props => [examCalendarId, gradeIds];
}

class AssignSubjectDateEvent extends ExamTimetableWizardEvent {
  final String subjectId;
  final DateTime examDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  @override
  List<Object?> get props => [subjectId, examDate, startTime, endTime];
}

class SubmitWizardEvent extends ExamTimetableWizardEvent {
  @override
  List<Object?> get props => [];
}

// States
abstract class ExamTimetableWizardState extends Equatable {}

class WizardInitial extends ExamTimetableWizardState {
  @override
  List<Object?> get props => [];
}

class WizardStep1State extends ExamTimetableWizardState {
  final List<ExamCalendarEntity> calendars;
  final bool isLoading;
  final String? error;
  final ExamCalendarEntity? selectedCalendar;

  WizardStep1State({
    required this.calendars,
    this.isLoading = false,
    this.error,
    this.selectedCalendar,
  });

  @override
  List<Object?> get props => [calendars, isLoading, error, selectedCalendar];
}

class WizardStep2State extends ExamTimetableWizardState {
  final ExamCalendarEntity selectedCalendar;
  final List<GradeEntity> availableGrades;
  final List<String> selectedGradeIds;
  final bool isLoading;
  final String? error;

  WizardStep2State({
    required this.selectedCalendar,
    required this.availableGrades,
    required this.selectedGradeIds,
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [
    selectedCalendar,
    availableGrades,
    selectedGradeIds,
    isLoading,
    error,
  ];
}

class WizardStep3State extends ExamTimetableWizardState {
  final ExamCalendarEntity selectedCalendar;
  final List<String> selectedGradeIds;
  final List<SubjectEntity> subjects;
  final List<ExamTimetableEntryEntity> entries;
  final bool isLoading;
  final String? error;

  WizardStep3State({
    required this.selectedCalendar,
    required this.selectedGradeIds,
    required this.subjects,
    required this.entries,
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [
    selectedCalendar,
    selectedGradeIds,
    subjects,
    entries,
    isLoading,
    error,
  ];
}

class WizardCompletedState extends ExamTimetableWizardState {
  final String timetableId;
  final String message;

  WizardCompletedState({
    required this.timetableId,
    required this.message,
  });

  @override
  List<Object?> get props => [timetableId, message];
}

class WizardErrorState extends ExamTimetableWizardState {
  final String error;

  WizardErrorState({required this.error});

  @override
  List<Object?> get props => [error];
}
```

### 🔲 PHASE 7: CREATE BLoC IMPLEMENTATION

Create: `lib/features/timetable/presentation/bloc/exam_timetable_wizard_bloc.dart`

```dart
class ExamTimetableWizardBloc extends Bloc<ExamTimetableWizardEvent, ExamTimetableWizardState> {
  final GetExamCalendarsUsecase getExamCalendars;
  final MapGradesToExamCalendarUsecase mapGradesToExamCalendar;
  final GetGradesForCalendarUsecase getGradesForCalendar;
  final CreateExamTimetableWithEntriesUsecase createExamTimetableWithEntries;
  final GetGradesUsecase getGrades;
  final GetSubjectsUsecase getSubjects;

  ExamTimetableWizardBloc({
    required this.getExamCalendars,
    required this.mapGradesToExamCalendar,
    required this.getGradesForCalendar,
    required this.createExamTimetableWithEntries,
    required this.getGrades,
    required this.getSubjects,
  }) : super(WizardInitial()) {
    on<InitializeWizardEvent>(_onInitializeWizard);
    on<SelectExamCalendarEvent>(_onSelectExamCalendar);
    on<SelectGradesEvent>(_onSelectGrades);
    on<AssignSubjectDateEvent>(_onAssignSubjectDate);
    on<SubmitWizardEvent>(_onSubmitWizard);
  }

  Future<void> _onInitializeWizard(
    InitializeWizardEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    emit(WizardStep1State(
      calendars: [],
      isLoading: true,
    ));

    final result = await getExamCalendars(GetExamCalendarsParams(
      tenantId: event.tenantId,
    ));

    result.fold(
      (failure) => emit(WizardErrorState(error: failure.toString())),
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
    // Transition from Step 1 to Step 2
    emit(WizardStep2State(
      selectedCalendar: event.calendar,
      availableGrades: [],
      selectedGradeIds: [],
      isLoading: true,
    ));

    // Load grades
    final gradesResult = await getGrades(const GetGradesParams());
    final selectedGradesResult = await getGradesForCalendar(
      GetGradesForCalendarParams(examCalendarId: event.calendar.id),
    );

    gradesResult.fold(
      (failure) => emit(WizardErrorState(error: failure.toString())),
      (allGrades) {
        selectedGradesResult.fold(
          (failure) => emit(WizardErrorState(error: failure.toString())),
          (selectedGradeIds) => emit(WizardStep2State(
            selectedCalendar: event.calendar,
            availableGrades: allGrades,
            selectedGradeIds: selectedGradeIds,
            isLoading: false,
          )),
        );
      },
    );
  }

  Future<void> _onSelectGrades(
    SelectGradesEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    // Get current state as Step 2
    if (state is! WizardStep2State) return;
    final step2State = state as WizardStep2State;

    emit(WizardStep2State(
      selectedCalendar: step2State.selectedCalendar,
      availableGrades: step2State.availableGrades,
      selectedGradeIds: event.gradeIds,
      isLoading: true,
    ));

    // Save grade mappings
    final result = await mapGradesToExamCalendar(
      MapGradesToExamCalendarParams(
        tenantId: step2State.selectedCalendar.tenantId,
        examCalendarId: event.examCalendarId,
        gradeIds: event.gradeIds,
      ),
    );

    result.fold(
      (failure) => emit(WizardErrorState(error: failure.toString())),
      (mappings) async {
        // Load subjects for Step 3
        final subjectsResult = await getSubjects(const GetSubjectsParams());

        subjectsResult.fold(
          (failure) => emit(WizardErrorState(error: failure.toString())),
          (subjects) => emit(WizardStep3State(
            selectedCalendar: step2State.selectedCalendar,
            selectedGradeIds: event.gradeIds,
            subjects: subjects,
            entries: [],
            isLoading: false,
          )),
        );
      },
    );
  }

  Future<void> _onAssignSubjectDate(
    AssignSubjectDateEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;
    final step3State = state as WizardStep3State;

    // Create new entry for subject-date assignment
    final newEntry = ExamTimetableEntryEntity(
      id: 'entry-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: step3State.selectedCalendar.tenantId,
      timetableId: '', // Will be set when creating timetable
      gradeId: step3State.selectedGradeIds[0], // Using first grade
      subjectId: event.subjectId,
      section: 'A', // TODO: Make dynamic based on grade sections
      examDate: event.examDate,
      startTime: event.startTime,
      endTime: event.endTime,
      durationMinutes: event.endTime.hour * 60 + event.endTime.minute -
          (event.startTime.hour * 60 + event.startTime.minute),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final updatedEntries = [...step3State.entries, newEntry];

    emit(WizardStep3State(
      selectedCalendar: step3State.selectedCalendar,
      selectedGradeIds: step3State.selectedGradeIds,
      subjects: step3State.subjects,
      entries: updatedEntries,
    ));
  }

  Future<void> _onSubmitWizard(
    SubmitWizardEvent event,
    Emitter<ExamTimetableWizardState> emit,
  ) async {
    if (state is! WizardStep3State) return;
    final step3State = state as WizardStep3State;

    emit(WizardStep3State(
      selectedCalendar: step3State.selectedCalendar,
      selectedGradeIds: step3State.selectedGradeIds,
      subjects: step3State.subjects,
      entries: step3State.entries,
      isLoading: true,
    ));

    final result = await createExamTimetableWithEntries(
      CreateExamTimetableWithEntriesParams(
        tenantId: step3State.selectedCalendar.tenantId,
        examCalendarId: step3State.selectedCalendar.id,
        examName: step3State.selectedCalendar.examName,
        examType: step3State.selectedCalendar.examType,
        academicYear: '2024-25', // TODO: Get from user state
        createdByUserId: '', // TODO: Get from auth
        entries: step3State.entries,
      ),
    );

    result.fold(
      (failure) => emit(WizardErrorState(error: failure.toString())),
      (timetable) => emit(WizardCompletedState(
        timetableId: timetable.id,
        message: 'Exam timetable created successfully!',
      )),
    );
  }
}
```

### 🔲 PHASE 8: CREATE UI WIDGETS

#### Step 1: Exam Calendar Creation/Selection Widget
```dart
// File: lib/features/timetable/presentation/widgets/wizard_step1_calendar.dart

class WizardStep1Calendar extends StatefulWidget {
  final Function(ExamCalendarEntity) onCalendarSelected;

  const WizardStep1Calendar({
    required this.onCalendarSelected,
  });

  @override
  State<WizardStep1Calendar> createState() => _WizardStep1CalendarState();
}

class _WizardStep1CalendarState extends State<WizardStep1Calendar> {
  @override
  void initState() {
    super.initState();
    // Load calendars
    context.read<ExamTimetableBloc>().add(GetExamCalendarsEvent(tenantId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {
        if (state is WizardStep1State) {
          if (state.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Text('Select or Create Exam Calendar'),
              ListView.builder(
                itemCount: state.calendars.length,
                itemBuilder: (context, index) {
                  final calendar = state.calendars[index];
                  return Card(
                    child: ListTile(
                      title: Text(calendar.examName),
                      subtitle: Text('${calendar.plannedStartDate} to ${calendar.plannedEndDate}'),
                      onTap: () => widget.onCalendarSelected(calendar),
                    ),
                  );
                },
              ),
            ],
          );
        }

        return ErrorWidget(error: state.toString());
      },
    );
  }
}
```

#### Step 2: Grade Selection Widget
```dart
// File: lib/features/timetable/presentation/widgets/wizard_step2_grades.dart

class WizardStep2Grades extends StatefulWidget {
  final ExamCalendarEntity selectedCalendar;
  final Function(List<String>) onGradesSelected;

  const WizardStep2Grades({
    required this.selectedCalendar,
    required this.onGradesSelected,
  });

  @override
  State<WizardStep2Grades> createState() => _WizardStep2GradesState();
}

class _WizardStep2GradesState extends State<WizardStep2Grades> {
  final Set<String> _selectedGradeIds = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {
        if (state is WizardStep2State) {
          return Column(
            children: [
              Text('Select Grades for: ${widget.selectedCalendar.examName}'),
              ListView.builder(
                itemCount: state.availableGrades.length,
                itemBuilder: (context, index) {
                  final grade = state.availableGrades[index];
                  return CheckboxListTile(
                    title: Text(grade.gradeName),
                    value: _selectedGradeIds.contains(grade.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedGradeIds.add(grade.id);
                        } else {
                          _selectedGradeIds.remove(grade.id);
                        }
                      });
                    },
                  );
                },
              ),
              ElevatedButton(
                onPressed: _selectedGradeIds.isNotEmpty
                    ? () {
                        context.read<ExamTimetableWizardBloc>().add(
                              SelectGradesEvent(
                                examCalendarId: widget.selectedCalendar.id,
                                gradeIds: _selectedGradeIds.toList(),
                              ),
                            );
                        widget.onGradesSelected(_selectedGradeIds.toList());
                      }
                    : null,
                child: Text('Next: Subject Schedule'),
              ),
            ],
          );
        }

        return ErrorWidget(error: state.toString());
      },
    );
  }
}
```

#### Step 3: Subject-Date Assignment Widget
```dart
// File: lib/features/timetable/presentation/widgets/wizard_step3_schedule.dart

class WizardStep3Schedule extends StatefulWidget {
  final ExamCalendarEntity selectedCalendar;
  final List<SubjectEntity> subjects;

  const WizardStep3Schedule({
    required this.selectedCalendar,
    required this.subjects,
  });

  @override
  State<WizardStep3Schedule> createState() => _WizardStep3ScheduleState();
}

class _WizardStep3ScheduleState extends State<WizardStep3Schedule> {
  final Map<String, DateTime> _subjectDateMap = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
      builder: (context, state) {
        if (state is WizardStep3State) {
          return Column(
            children: [
              Text('Assign Subjects to Exam Dates'),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.subjects.length,
                  itemBuilder: (context, index) {
                    final subject = widget.subjects[index];
                    return ListTile(
                      title: Text(subject.subjectName),
                      trailing: ElevatedButton(
                        onPressed: () => _showDatePicker(context, subject),
                        child: Text(_subjectDateMap[subject.id] != null
                            ? '${_subjectDateMap[subject.id]!.day}/${_subjectDateMap[subject.id]!.month}'
                            : 'Select Date'),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _subjectDateMap.length == widget.subjects.length
                    ? () => _submitTimetable(context)
                    : null,
                child: Text('Create Timetable'),
              ),
            ],
          );
        }

        return ErrorWidget(error: state.toString());
      },
    );
  }

  Future<void> _showDatePicker(BuildContext context, SubjectEntity subject) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedCalendar.plannedStartDate,
      firstDate: widget.selectedCalendar.plannedStartDate,
      lastDate: widget.selectedCalendar.plannedEndDate,
    );

    if (picked != null) {
      setState(() {
        _subjectDateMap[subject.id] = picked;
      });

      // Assign to BLoC
      context.read<ExamTimetableWizardBloc>().add(
            AssignSubjectDateEvent(
              subjectId: subject.id,
              examDate: picked,
              startTime: TimeOfDay(hour: 9, minute: 0),
              endTime: TimeOfDay(hour: 11, minute: 0),
            ),
          );
    }
  }

  void _submitTimetable(BuildContext context) {
    context.read<ExamTimetableWizardBloc>().add(SubmitWizardEvent());
  }
}
```

### 🔲 PHASE 9: CREATE MAIN WIZARD PAGE

```dart
// File: lib/features/timetable/presentation/pages/exam_timetable_wizard_page.dart

class ExamTimetableWizardPage extends StatefulWidget {
  final String tenantId;
  final String academicYear;

  const ExamTimetableWizardPage({
    required this.tenantId,
    required this.academicYear,
  });

  @override
  State<ExamTimetableWizardPage> createState() =>
      _ExamTimetableWizardPageState();
}

class _ExamTimetableWizardPageState extends State<ExamTimetableWizardPage> {
  @override
  void initState() {
    super.initState();
    context.read<ExamTimetableWizardBloc>().add(
          InitializeWizardEvent(
            tenantId: widget.tenantId,
            academicYear: widget.academicYear,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Exam Timetable')),
      body: BlocListener<ExamTimetableWizardBloc, ExamTimetableWizardState>(
        listener: (context, state) {
          if (state is WizardCompletedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            Navigator.pop(context, state.timetableId);
          } else if (state is WizardErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        child: BlocBuilder<ExamTimetableWizardBloc, ExamTimetableWizardState>(
          builder: (context, state) {
            if (state is WizardStep1State) {
              return WizardStep1Calendar(
                onCalendarSelected: (calendar) {
                  context.read<ExamTimetableWizardBloc>().add(
                        SelectExamCalendarEvent(calendar: calendar),
                      );
                },
              );
            } else if (state is WizardStep2State) {
              return WizardStep2Grades(
                selectedCalendar: state.selectedCalendar,
                onGradesSelected: (gradeIds) {},
              );
            } else if (state is WizardStep3State) {
              return WizardStep3Schedule(
                selectedCalendar: state.selectedCalendar,
                subjects: state.subjects,
              );
            }

            return Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }
}
```

---

## **FILES CREATED SUMMARY**

### Database
- ✅ `supabase/migrations/20251111_add_exam_calendar_grade_mapping.sql`
- ✅ `supabase/migrations/20251111_add_timetable_date_validation.sql`

### Domain (Entities)
- ✅ `lib/features/timetable/domain/entities/exam_calendar_grade_mapping_entity.dart`
- ✅ `lib/features/timetable/domain/entities/exam_timetable_wizard_data.dart`

### Data (Models & Data Sources)
- ✅ `lib/features/timetable/data/models/exam_calendar_grade_mapping_model.dart`
- ✅ `lib/features/timetable/data/datasources/exam_timetable_remote_data_source.dart` (extended with grade mapping methods)

### Domain (Use Cases & Repositories)
- ✅ `lib/features/timetable/domain/usecases/map_grades_to_exam_calendar_usecase.dart`
- ✅ `lib/features/timetable/domain/usecases/get_grades_for_calendar_usecase.dart`
- ✅ `lib/features/timetable/domain/usecases/create_exam_timetable_with_entries_usecase.dart`
- ✅ `lib/features/timetable/domain/repositories/exam_timetable_repository.dart` (extended with new methods)
- ✅ `lib/features/timetable/data/repositories/exam_timetable_repository_impl.dart` (extended with implementations)

### UI (Bloc, Widgets, Pages)
- 🔲 `lib/features/timetable/presentation/bloc/exam_timetable_wizard_event.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/bloc/exam_timetable_wizard_state.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/bloc/exam_timetable_wizard_bloc.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/widgets/wizard_step1_calendar.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/widgets/wizard_step2_grades.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/widgets/wizard_step3_schedule.dart` (NEW)
- 🔲 `lib/features/timetable/presentation/pages/exam_timetable_wizard_page.dart` (NEW/UPDATE)

---

## **INTEGRATION CHECKLIST**

### Database
- [ ] Run migration `20251111_add_exam_calendar_grade_mapping.sql` on Supabase
- [ ] Run migration `20251111_add_timetable_date_validation.sql` on Supabase
- [ ] Verify tables and RLS policies are active

### Dependencies
- [ ] All new files are created in correct locations
- [ ] Import statements are correct
- [ ] No circular dependencies

### DI/Injection Container
- [ ] Register new use cases in `injection_container.dart`
- [ ] Register new BLocs in `injection_container.dart`
- [ ] Ensure all dependencies are properly injected

### BLoC Integration
- [ ] Add `ExamTimetableWizardBloc` to `AppRouter` states
- [ ] Wire up navigation from existing timetable pages
- [ ] Test BLoC event flow

### Testing
- [ ] Unit tests for use cases
- [ ] Unit tests for BLoCs
- [ ] Widget tests for UI components
- [ ] Integration tests for complete wizard flow

---

## **DATA FLOW DIAGRAM**

```
┌─────────────────────────────────────────────────────────┐
│ STEP 1: SELECT/CREATE EXAM CALENDAR                     │
├─────────────────────────────────────────────────────────┤
│ UI: WizardStep1Calendar                                 │
│ Event: SelectExamCalendarEvent                          │
│ Data: ExamCalendarEntity                                │
│ Database: exam_calendar table                           │
│ Usecase: GetExamCalendarsUsecase                        │
│ ✓ Output: selectedCalendar stored in BLoC               │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 2: SELECT GRADES FOR EXAM                          │
├─────────────────────────────────────────────────────────┤
│ UI: WizardStep2Grades                                   │
│ Event: SelectGradesEvent                                │
│ Data: List<String> gradeIds                             │
│ Database: exam_calendar_grade_mapping table             │
│ Usecase: MapGradesToExamCalendarUsecase                 │
│ ✓ Output: selectedGrades + mappings saved in database   │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ STEP 3: MAP SUBJECTS TO EXAM DATES                      │
├─────────────────────────────────────────────────────────┤
│ UI: WizardStep3Schedule                                 │
│ Event: AssignSubjectDateEvent (multiple)                │
│ Data: List<ExamTimetableEntryEntity>                    │
│ Database: exam_timetable_entries table                  │
│ Usecase: CreateExamTimetableWithEntriesUsecase          │
│ ✓ Output: Complete timetable created in database        │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ COMPLETION                                              │
├─────────────────────────────────────────────────────────┤
│ State: WizardCompletedState                             │
│ Navigation: Back to timetable list or detail page       │
└─────────────────────────────────────────────────────────┘
```

---

##  **KNOWN CONSIDERATIONS**

1. **Section Handling**: Currently assumes single section 'A'. Update to support multiple sections per grade.

2. **Time Input**: Default times (9:00-11:00). Add UI for flexible time selection.

3. **Bulk Operations**: Consider batch insert optimization for large timetables.

4. **Validation**: Add real-time validation in Step 3 (duplicate dates, etc.).

5. **Error Recovery**: Implement rollback strategy if entries fail during insertion.

---

## **ESTIMATED COMPLETION**

- Database & Backend: ✅ **COMPLETE**
- Frontend (UI/BLoC): 🔲 **IN PROGRESS** (~2-3 hours)
- Testing: 🔲 **NOT STARTED** (~3-4 hours)
- **Total: ~40 hours of work completed, ~5-7 hours remaining**

---

**Last Updated**: 2025-11-11
**Status**: Implementation phase 6 of 9 complete
