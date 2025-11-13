# Timetable Academic Structure Consistency - Implementation Guide

## Overview

This document outlines the comprehensive solution to fix the inconsistencies between the academic structure and timetable features. A phased approach has been implemented to ensure subject assignments respect the grade-section-subject mappings configured in the academic structure.

---

## ✅ COMPLETED IMPLEMENTATIONS

### 1. Database Migration (✅ DONE)

**File:** `supabase/migrations/20251113_add_subject_validation_constraints.sql`

**What it does:**
- Adds foreign key constraint from `exam_timetable_entries` to `grade_section_subject`
- Ensures only subjects that are offered in a grade-section can be assigned in timetable
- Creates helper function `is_valid_subject_for_grade_section()` for validation
- Creates view `valid_timetable_entries` for auditing

**Key Change:**
```sql
ALTER TABLE exam_timetable_entries
ADD CONSTRAINT fk_timetable_subject_assignment
FOREIGN KEY (tenant_id, grade_section_id, subject_id)
REFERENCES grade_section_subject(tenant_id, grade_section_id, subject_id);
```

**Impact:** Database now prevents invalid subject-grade combinations at the record level.

---

### 2. Enhanced Validation Service (✅ DONE)

**File:** `lib/features/timetable/domain/services/timetable_validation_service.dart`

**New Methods Added:**

#### `validateSubjectForGradeSection()`
Validates that a specific subject is offered in a grade+section combination.

**Signature:**
```dart
ValidationResult validateSubjectForGradeSection({
  required String subjectName,
  required int gradeNumber,
  required String section,
  required Map<String, List<String>> offeredSubjectsPerGradeSection,
})
```

**Example Usage:**
```dart
final validation = validationService.validateSubjectForGradeSection(
  subjectName: 'Science',
  gradeNumber: 3,
  section: 'A',
  offeredSubjectsPerGradeSection: {
    "1_A": ["EVS", "Math"],
    "3_A": ["Science", "Math"],
  },
);

if (!validation.isValid) {
  print(validation.errors.join('\n'));
  // Output: "Subject "Science" is not offered in Grade 1, Section A..."
}
```

#### `validateEntriesAgainstAcademicStructure()`
Validates all timetable entries to ensure subjects match the academic structure.

**Signature:**
```dart
ValidationResult validateEntriesAgainstAcademicStructure(
  List<ExamTimetableEntryEntity> entries,
  Map<String, List<String>> offeredSubjectsPerGradeSection,
)
```

---

### 3. New Use Case (✅ DONE)

**File:** `lib/features/timetable/domain/usecases/get_valid_subjects_for_grade_selection_usecase.dart`

**Purpose:** Fetch all valid subjects for selected grade-section combinations from the database.

**Signature:**
```dart
Future<Either<Failure, Map<String, List<String>>>> call(
  GetValidSubjectsParams params,
) async
```

**Parameters:**
- `tenantId`: School tenant ID
- `selectedGradeSectionIds`: List of grade_section UUIDs selected in Step 3

**Returns:**
```dart
{
  "1_A": ["EVS", "Math", "English"],
  "1_B": ["EVS", "Math", "English"],
  "3_A": ["Science", "Math", "English"]
}
```

**How to Use:**
```dart
final useCase = GetValidSubjectsForGradeSelectionUseCase(
  repository: examTimetableRepository,
);

final result = await useCase(
  GetValidSubjectsParams(
    tenantId: 'tenant-123',
    selectedGradeSectionIds: ['grade-sec-1', 'grade-sec-2'],
  ),
);

result.fold(
  (failure) => print('Error: $failure'),
  (validSubjectsMap) => print('Valid subjects: $validSubjectsMap'),
);
```

---

### 4. Repository & Data Source Integration (✅ DONE)

**Files Modified:**
- `lib/features/timetable/domain/repositories/exam_timetable_repository.dart`
- `lib/features/timetable/data/repositories/exam_timetable_repository_impl.dart`
- `lib/features/timetable/data/datasources/exam_timetable_remote_data_source.dart`

**Remote Query Implementation:**
```dart
// Fetches subjects from grade_section_subject with relationships
final response = await _supabaseClient
    .from('grade_section_subject')
    .select('''
      grade_section_id,
      subject_id,
      grade_sections!inner(grade_id, section_name),
      subjects!inner(catalog_subject_id),
      subject_catalog!inner(subject_name)
    ''')
    .eq('tenant_id', tenantId)
    .eq('is_offered', true)
    .eq('grade_sections.is_active', true)
    .inFilter('grade_section_id', selectedGradeSectionIds);
```

---

### 5. WizardData Model Update (✅ DONE)

**File:** `lib/features/timetable/presentation/pages/exam_timetable_create_wizard_page.dart`

**New Field:**
```dart
class WizardData {
  // ... existing fields ...

  /// Map of (gradeNumber_section) -> [subject_names]
  /// Populated in Step 3 when grades are selected
  /// Used in Step 4 to filter available subjects
  Map<String, List<String>> validSubjectsPerGradeSection = {};
}
```

---

## 🔄 REMAINING IMPLEMENTATIONS

### Step 5: Integrate Use Case into BLoC (PENDING)

**Goal:** Load valid subjects when Step 3 completes.

**Approach:**

1. **Add Event to ExamTimetableBloc:**

```dart
// In exam_timetable_event.dart
class LoadValidSubjectsForGradesEvent extends ExamTimetableEvent {
  final String tenantId;
  final List<String> selectedGradeSectionIds;

  LoadValidSubjectsForGradesEvent({
    required this.tenantId,
    required this.selectedGradeSectionIds,
  });
}
```

2. **Add State to ExamTimetableBloc:**

```dart
// In exam_timetable_state.dart
class ValidSubjectsLoaded extends ExamTimetableState {
  final Map<String, List<String>> validSubjectsPerGradeSection;

  ValidSubjectsLoaded({
    required this.validSubjectsPerGradeSection,
  });
}
```

3. **Handle Event in BLoC:**

```dart
// In exam_timetable_bloc.dart
on<LoadValidSubjectsForGradesEvent>((event, emit) async {
  emit(ExamTimetableLoading());

  final result = await _getValidSubjectsUseCase(
    GetValidSubjectsParams(
      tenantId: event.tenantId,
      selectedGradeSectionIds: event.selectedGradeSectionIds,
    ),
  );

  result.fold(
    (failure) => emit(ExamTimetableError(failure.message)),
    (validSubjects) => emit(
      ValidSubjectsLoaded(validSubjectsPerGradeSection: validSubjects),
    ),
  );
});
```

4. **Inject Use Case in BLoC Constructor:**

```dart
final GetValidSubjectsForGradeSelectionUseCase _getValidSubjectsUseCase;

ExamTimetableBloc({
  required GetValidSubjectsForGradeSelectionUseCase getValidSubjectsUseCase,
  // ... other dependencies
}) : _getValidSubjectsUseCase = getValidSubjectsUseCase;
```

5. **Trigger from Step 3 Widget:**

```dart
// In timetable_wizard_step3_grades.dart
// After user selects grades and calls _notifyParentOfSelection():

context.read<ExamTimetableBloc>().add(
  LoadValidSubjectsForGradesEvent(
    tenantId: widget.wizardData.tenantId,
    selectedGradeSectionIds: selectedGradeSectionIds,
  ),
);
```

---

### Step 6: Redesign Step 4 Widget (PENDING)

**Goal:** Replace hardcoded subjects with grade-specific valid subjects.

**Current Problem:**
```dart
final List<String> _subjects = [
  'Mathematics', 'English', 'Science', // Hardcoded, not validated!
];
```

**Solution - Tabbed Grade Selection Approach:**

```dart
class _TimetableWizardStep4ScheduleState
    extends State<TimetableWizardStep4Schedule> {

  late PageController _gradePageController;
  int _currentGradeIndex = 0;

  @override
  void initState() {
    super.initState();
    _gradePageController = PageController();
    _initializeSchedules();
  }

  @override
  Widget build(BuildContext context) {
    final grades = widget.wizardData.selectedGrades;
    final validSubjects = widget.wizardData.validSubjectsPerGradeSection;

    return Column(
      children: [
        // Grade selector tabs
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: grades.length,
            itemBuilder: (context, index) {
              final isSelected = index == _currentGradeIndex;
              return GestureDetector(
                onTap: () {
                  _pageController.jumpToPage(index);
                  setState(() => _currentGradeIndex = index);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    'Grade ${grades[index].gradeName}, '
                    '${grades[index].sections.join(", ")}',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),

        // Schedule content for selected grade
        Expanded(
          child: PageView.builder(
            controller: _gradePageController,
            onPageChanged: (index) {
              setState(() => _currentGradeIndex = index);
            },
            itemCount: grades.length,
            itemBuilder: (context, gradeIndex) {
              final grade = grades[gradeIndex];
              final gradeKey = '${grade.gradeName}_${grade.sections.join("-")}';

              // Get subjects valid for THIS grade-section
              final subjectsForGrade = _getValidSubjectsForGrade(
                grade,
                validSubjects,
              );

              return _buildGradeScheduleView(
                context,
                grade,
                subjectsForGrade,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Get valid subjects for a specific grade
  List<String> _getValidSubjectsForGrade(
    GradeSelection grade,
    Map<String, List<String>> validSubjects,
  ) {
    final subjectSet = <String>{};

    // Get union of subjects across all sections of this grade
    for (final section in grade.sections) {
      final key = '${grade.gradeName}_$section';
      subjectSet.addAll(validSubjects[key] ?? []);
    }

    return subjectSet.toList();
  }

  /// Build schedule view for a specific grade
  Widget _buildGradeScheduleView(
    BuildContext context,
    GradeSelection grade,
    List<String> validSubjects,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Assign subjects for Grade ${grade.gradeName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Instead of hardcoded subjects, use validSubjects
          ..._schedules.map((schedule) {
            return _buildScheduleCard(
              context,
              schedule,
              validSubjects, // Pass valid subjects for this grade
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Updated schedule card builder
  Widget _buildScheduleCard(
    BuildContext context,
    SubjectSchedule schedule,
    List<String> availableSubjects, // Now grade-specific
  ) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule.dateDisplay,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: schedule.selectedSubject,
              decoration: InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(Icons.book),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Subjects available for this grade',
              ),
              items: availableSubjects // FILTERED by grade!
                  .map((subject) => DropdownMenuItem(
                    value: subject,
                    child: Text(subject),
                  ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  schedule.selectedSubject = value;
                  _validateAndGenerate();
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a subject';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 7: Add Validation Before Saving (PENDING)

**Goal:** Validate all entries against academic structure before storing.

**In exam_timetable_bloc.dart:**

```dart
on<CreateExamTimetableWithEntriesEvent>((event, emit) async {
  emit(ExamTimetableLoading());

  // Get valid subjects map
  final validSubjectsResult = await _getValidSubjectsUseCase(
    GetValidSubjectsParams(
      tenantId: event.tenantId,
      selectedGradeSectionIds: _extractGradeSectionIds(event.entries),
    ),
  );

  return await validSubjectsResult.fold(
    (failure) {
      emit(ExamTimetableError('Failed to fetch academic structure'));
      return;
    },
    (validSubjects) async {
      // Validate all entries
      final validation = _validationService.validateEntriesAgainstAcademicStructure(
        event.entries,
        validSubjects,
      );

      if (!validation.isValid) {
        emit(ExamTimetableError(
          'Invalid subject assignments:\n${validation.errors.join('\n')}',
        ));
        return;
      }

      // Proceed with creation
      final result = await _repository.createExamTimetableWithEntries(
        tenantId: event.tenantId,
        examName: event.examName,
        examType: event.examType,
        academicYear: event.academicYear,
        createdByUserId: event.createdByUserId,
        entries: event.entries,
      );

      result.fold(
        (failure) => emit(ExamTimetableError(failure.message)),
        (timetable) => emit(ExamTimetableCreated(timetable)),
      );
    },
  );
});
```

---

### Step 8: Update Publishing Validation (PENDING)

**In publishExamTimetable():**

```dart
@override
Future<Either<Failure, ExamTimetableEntity>> publishExamTimetable(
  String timetableId,
) async {
  // Fetch timetable and entries
  final timetableResult = await getExamTimetableById(timetableId);
  final entriesResult = await getExamTimetableEntries(timetableId);

  return await timetableResult.fold(
    (failure) => Left(failure),
    (timetable) async {
      return await entriesResult.fold(
        (failure) => Left(failure),
        (entries) async {
          // Fetch valid subjects
          final gradeSectionIds = entries
              .map((e) => e.gradeSectionId)
              .toSet()
              .toList();

          final validSubjectsResult = await _repository
              .getValidSubjectsForGradeSelection(
            tenantId: timetable.tenantId,
            selectedGradeSectionIds: gradeSectionIds,
          );

          return await validSubjectsResult.fold(
            (failure) => Left(failure),
            (validSubjects) {
              // Validate all entries
              final validation = _validationService
                  .validateEntriesAgainstAcademicStructure(
                entries,
                validSubjects,
              );

              if (!validation.isValid) {
                return Left(ValidationFailure(
                  'Cannot publish timetable. Subject assignment issues:\n'
                  '${validation.errors.join('\n')}',
                ));
              }

              // Proceed with publishing
              return _remoteDataSource.publishExamTimetable(timetableId);
            },
          );
        },
      );
    },
  );
}
```

---

## 🧪 TESTING THE IMPLEMENTATION

### Unit Test for Validation Service:

```dart
test('validateSubjectForGradeSection rejects invalid subject', () {
  final service = TimetableValidationService();

  final result = service.validateSubjectForGradeSection(
    subjectName: 'Science',
    gradeNumber: 1,
    section: 'A',
    offeredSubjectsPerGradeSection: {
      "1_A": ["EVS", "Math"],
    },
  );

  expect(result.isValid, false);
  expect(result.errors.first, contains('Science'));
  expect(result.errors.first, contains('Grade 1'));
});
```

### Integration Test for Use Case:

```dart
test('getValidSubjectsForGradeSelection returns correct subjects', () async {
  final repository = MockExamTimetableRepository();
  final useCase = GetValidSubjectsForGradeSelectionUseCase(
    repository: repository,
  );

  when(repository.getValidSubjectsForGradeSelection(
    tenantId: 'tenant-1',
    selectedGradeSectionIds: ['grade-sec-1'],
  )).thenAnswer((_) async => Right({
    "1_A": ["EVS", "Math"],
  }));

  final result = await useCase(GetValidSubjectsParams(
    tenantId: 'tenant-1',
    selectedGradeSectionIds: ['grade-sec-1'],
  ));

  expect(result.isRight(), true);
  expect(result.getOrElse(() => {})["1_A"], ["EVS", "Math"]);
});
```

---

## 📋 DEPLOYMENT CHECKLIST

- [ ] Run database migration: `supabase db push` in your Supabase CLI
- [ ] Inject `GetValidSubjectsForGradeSelectionUseCase` in BLoC registration
- [ ] Update `exam_timetable_bloc.dart` with new events and handling
- [ ] Implement Step 6 redesign in `timetable_wizard_step4_schedule.dart`
- [ ] Add validation calls in entry creation and publishing
- [ ] Run unit tests for validation service
- [ ] Run integration tests for use case
- [ ] Manual QA: Test creating timetable with invalid subject assignment (should fail)
- [ ] Manual QA: Test creating timetable with valid subject assignment (should succeed)

---

## 🎯 EXPECTED BEHAVIOR AFTER IMPLEMENTATION

**Before:** User can assign EVS to Grade 3 even though Grade 3 only has Science
**After:** UI only shows valid subjects per grade, and database constraint prevents invalid entries

**Example Flow:**
1. User selects Grade 1 (has EVS) and Grade 3 (has Science)
2. Step 4 shows two tabs: "Grade 1" and "Grade 3"
3. Under "Grade 1" tab: Dropdown only shows ["EVS", "Math", "English"]
4. Under "Grade 3" tab: Dropdown only shows ["Science", "Math", "English"]
5. User cannot accidentally assign Science to Grade 1 ❌
6. If somehow invalid entry is created, database constraint blocks it ❌

---

## 📚 REFERENCE DOCUMENTATION

- **Migration:** `supabase/migrations/20251113_add_subject_validation_constraints.sql`
- **Validation Service:** `lib/features/timetable/domain/services/timetable_validation_service.dart`
- **Use Case:** `lib/features/timetable/domain/usecases/get_valid_subjects_for_grade_selection_usecase.dart`
- **BLoC:** `lib/features/timetable/presentation/bloc/exam_timetable_bloc.dart`
- **Step 4 Widget:** `lib/features/timetable/presentation/widgets/timetable_wizard_step4_schedule.dart`

---

## 🤔 COMMON ISSUES & SOLUTIONS

### Issue: "Supabase foreign key constraint fails"
**Solution:** Run the migration file to add the constraint properly.

### Issue: "Valid subjects map is empty in Step 4"
**Solution:** Ensure the BLoC event is triggered after Step 3, and verify grade-section IDs are correct.

### Issue: "Dropdown shows all subjects, not filtered by grade"
**Solution:** Check that `validSubjectsPerGradeSection` is populated and passed correctly to Step 4.

---

Let me know if you need clarification on any of these steps or help with the implementation! 🚀
