# Exam Timetable System - Frontend UI Planning

## Overview

This document outlines the frontend implementation plan for the exam timetable system, including UI components, screen flows, state management, and user interactions.

---

## Navigation Architecture

### Route Map

```
AppRoutes
├── /dashboard
│   ├── /admin (admin-specific dashboard)
│   │   ├── /exam-calendar
│   │   │   ├── /exam-calendar/create
│   │   │   └── /exam-calendar/:id/view
│   │   ├── /exam-timetable
│   │   │   ├── /exam-timetable/create
│   │   │   ├── /exam-timetable/:id/edit
│   │   │   ├── /exam-timetable/:id/entries
│   │   │   │   └── /exam-timetable/:id/entries/add
│   │   │   └── /exam-timetable/:id/publish
│   │   └── /sections
│   │       └── /sections/manage
│   └── /teacher (teacher-specific dashboard)
│       └── /papers
│           └── /papers/:paperId/view
├── /onboarding
│   └── /teacher-profile-setup (refactored)
└── /settings
    └── /grade-sections (admin only)
```

### Navigation Flow

```
Authentication
    ↓
User Role Check
    ├→ ADMIN
    │   └→ AdminDashboard
    │       ├→ ExamCalendarListPage
    │       │   └→ ExamCalendarCreatePage
    │       └→ ExamTimetableListPage
    │           ├→ ExamTimetableCreatePage
    │           ├→ ExamTimetableEditPage
    │           │   └→ AddTimetableEntryPage
    │           └→ PublishTimetablePage (confirmation)
    │
    └→ TEACHER
        ├→ Onboarding Check (first_login)
        │   └→ TeacherProfileSetupPage (REFACTORED)
        └→ TeacherDashboard
            └→ QuestionPaperDetailPage (existing)
```

---

## Teacher Onboarding Refactor (Priority 1)

### Current State
- Teachers select Grades (checkboxes)
- Teachers select Subjects (checkboxes)
- Result: Cartesian product assignment

### New State (Refactored)

**File**: `lib/features/onboarding/presentation/pages/teacher_profile_setup_page.dart`

**New UI**: Interactive Grid Selection

```
┌─────────────────────────────────────┐
│ Set Up Your Profile                 │
│                                     │
│ You're teaching at School ABC       │
│ Academic Year: 2024-2025            │
├─────────────────────────────────────┤
│                                     │
│ Select Your Classes                 │
│                                     │
│ [Grade 5]  [Grade 6]  [Grade 7]    │
│                                     │
│ Grade 5 Sections: A, B, C          │
│                                     │
│              Maths  English  Science │
│ Section A    [ ✓  ]   [ ✓  ]   [ ]  │
│ Section B    [ ✓  ]   [  ]    [ ✓ ] │
│ Section C    [  ]     [  ]    [ ]   │
│                                     │
│ Grade 6 Sections: A, B             │
│                                     │
│              Maths  English  Science │
│ Section A    [ ✓  ]   [  ]    [ ✓ ] │
│ Section B    [  ]     [ ✓  ]   [ ]  │
│                                     │
│ [  Continue to Dashboard  ]         │
└─────────────────────────────────────┘
```

**Component Structure**:

```dart
// lib/features/onboarding/presentation/pages/teacher_profile_setup_page.dart

class TeacherProfileSetupPage extends StatefulWidget {
  @override
  State<TeacherProfileSetupPage> createState() =>
      _TeacherProfileSetupPageState();
}

class _TeacherProfileSetupPageState extends State<TeacherProfileSetupPage> {
  // Map<GradeId, Set<(SectionName, SubjectId)>>
  final Map<String, Set<(String, String)>> _selectedAssignments = {};

  @override
  void initState() {
    super.initState();
    _loadGradesAndSubjects();
  }

  void _loadGradesAndSubjects() {
    context.read<GradeBloc>().add(const LoadGrades());
    context.read<SubjectBloc>().add(const LoadSubjects());
    context.read<GradeSectionBloc>().add(const LoadGradeSections());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              BlocBuilder<GradeBloc, GradeState>(
                builder: (context, gradeState) {
                  if (gradeState is! GradesLoaded) {
                    return const CircularProgressIndicator();
                  }
                  return BlocBuilder<GradeSectionBloc, GradeSectionState>(
                    builder: (context, sectionState) {
                      if (sectionState is! GradeSectionsLoaded) {
                        return const CircularProgressIndicator();
                      }
                      return BlocBuilder<SubjectBloc, SubjectState>(
                        builder: (context, subjectState) {
                          if (subjectState is! SubjectsLoaded) {
                            return const CircularProgressIndicator();
                          }
                          return _buildGradeSelectionGrid(
                            gradeState.grades,
                            sectionState.sections,
                            subjectState.subjects,
                          );
                        },
                      );
                    },
                  );
                },
              ),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeSelectionGrid(
    List<Grade> grades,
    List<GradeSection> sections,
    List<Subject> subjects,
  ) {
    return Column(
      children: grades.map((grade) {
        final gradeSections = sections
            .where((s) => s.gradeId == grade.id)
            .toList();

        return _buildGradeCard(grade, gradeSections, subjects);
      }).toList(),
    );
  }

  Widget _buildGradeCard(
    Grade grade,
    List<GradeSection> sections,
    List<Subject> subjects,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${grade.displayName} Sections: ${sections.map((s) => s.sectionName).join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Section')),
                ...subjects.map(
                  (subject) => DataColumn(label: Text(subject.name)),
                ),
              ],
              rows: sections.map((section) {
                return DataRow(
                  cells: [
                    DataCell(Text(section.sectionName)),
                    ...subjects.map((subject) {
                      final key = (section.sectionName, subject.id);
                      final isSelected =
                          _selectedAssignments[grade.id]?.contains(key) ?? false;

                      return DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              _selectedAssignments
                                  .putIfAbsent(grade.id, () => {});
                              if (value == true) {
                                _selectedAssignments[grade.id]?.add(key);
                              } else {
                                _selectedAssignments[grade.id]?.remove(key);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAssignments() async {
    // Convert selected assignments to TeacherSubject list
    final assignments = <TeacherSubject>[];

    _selectedAssignments.forEach((gradeId, selections) {
      for (final (section, subjectId) in selections) {
        assignments.add(
          TeacherSubject(
            tenantId: userStateService.currentTenant!.id,
            teacherId: userStateService.currentUserId!,
            gradeId: gradeId,
            subjectId: subjectId,
            section: section,
            academicYear: userStateService.currentAcademicYear!,
            isActive: true,
          ),
        );
      }
    });

    // Save using existing SaveTeacherAssignmentsUseCase
    // (but updated to handle teacher_subjects instead of grade/subject separately)
    context.read<AuthBloc>().add(AuthCheckStatus());
    context.go(AppRoutes.home);
  }
}
```

**New Blocs Needed**:
- `GradeSectionBloc` - Load grade sections for each grade
- Extend existing `SubjectBloc` if needed

---

## Admin UI Screens (Priority 2)

### 1. Exam Calendar Management

**Route**: `/admin/exam-calendar`

**Screen: ExamCalendarListPage**

```
┌────────────────────────────────────┐
│ Exam Calendar                      │
│                        [+ New]     │
├────────────────────────────────────┤
│                                    │
│ 2024-2025 Academic Year            │
│                                    │
│ [June Monthly Test]               │
│  Planned: Jun 15 - Jun 30         │
│  Deadline: Jun 10                 │
│  Status: Active ✓                 │
│                                    │
│ [September Quarterly]             │
│  Planned: Sep 15 - Sep 30         │
│  Deadline: Sep 10                 │
│  Status: Active ✓                 │
│                                    │
│ [December Half-Yearly]            │
│  Planned: Dec 10 - Dec 30         │
│  Deadline: Dec 5                  │
│  Status: Active ✓                 │
│                                    │
│ + Add More                         │
└────────────────────────────────────┘
```

**Screen: ExamCalendarCreatePage**

```
┌────────────────────────────────────┐
│ Create New Exam                    │
├────────────────────────────────────┤
│                                    │
│ Exam Name                          │
│ [_________________ June Monthly] │
│                                    │
│ Exam Type                          │
│ [ Monthly Test ▼ ]                │
│                                    │
│ Month                              │
│ [ 6 (June) ▼ ]                    │
│                                    │
│ Planned Start Date                 │
│ [2024-06-15] [📅]                │
│                                    │
│ Planned End Date                   │
│ [2024-06-30] [📅]                │
│                                    │
│ Paper Submission Deadline (optional)│
│ [2024-06-10] [📅]                │
│                                    │
│ Display Order                      │
│ [1] (for sorting)                 │
│                                    │
│ Additional Metadata (optional)     │
│ [________________________________ │
│  ________________________________ │
│  ________________________________ │
│                                    │
│ [  Create  ] [  Cancel  ]          │
└────────────────────────────────────┘
```

**Component**:

```dart
class ExamCalendarCreatePage extends StatefulWidget {
  @override
  State<ExamCalendarCreatePage> createState() =>
      _ExamCalendarCreatePageState();
}

class _ExamCalendarCreatePageState extends State<ExamCalendarCreatePage> {
  late TextEditingController _examNameController;
  late TextEditingController _displayOrderController;
  String _selectedExamType = 'monthlyTest';
  int _selectedMonth = 6;
  DateTime? _plannedStartDate;
  DateTime? _plannedEndDate;
  DateTime? _submissionDeadline;

  @override
  void dispose() {
    _examNameController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, Function(DateTime) onSelect) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onSelect(picked);
    }
  }

  Future<void> _createExamCalendar() async {
    if (_plannedStartDate == null || _plannedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select dates')),
      );
      return;
    }

    context.read<ExamCalendarBloc>().add(
      CreateExamCalendarEvent(
        examName: _examNameController.text,
        examType: _selectedExamType,
        monthNumber: _selectedMonth,
        plannedStartDate: _plannedStartDate!,
        plannedEndDate: _plannedEndDate!,
        submissionDeadline: _submissionDeadline,
        displayOrder: int.tryParse(_displayOrderController.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Exam')),
      body: BlocListener<ExamCalendarBloc, ExamCalendarState>(
        listener: (context, state) {
          if (state is ExamCalendarCreateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exam calendar created')),
            );
            context.pop();
          }
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Form fields...
                TextField(
                  controller: _examNameController,
                  decoration: const InputDecoration(labelText: 'Exam Name'),
                ),
                DropdownButton<String>(
                  value: _selectedExamType,
                  items: const [
                    DropdownMenuItem(
                      value: 'monthlyTest',
                      child: Text('Monthly Test'),
                    ),
                    DropdownMenuItem(
                      value: 'quarterlyTest',
                      child: Text('Quarterly Test'),
                    ),
                    DropdownMenuItem(
                      value: 'halfYearlyTest',
                      child: Text('Half-Yearly Test'),
                    ),
                    DropdownMenuItem(
                      value: 'finalExam',
                      child: Text('Final Exam'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedExamType = value ?? 'monthlyTest');
                  },
                ),
                // More form fields...
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### 2. Exam Timetable Management

**Route**: `/admin/exam-timetable`

**Screen: ExamTimetableListPage**

```
┌─────────────────────────────────────┐
│ Exam Timetables                    │
│                        [+ New]     │
├─────────────────────────────────────┤
│ Filter: [Draft ▼] [2024-2025 ▼]   │
├─────────────────────────────────────┤
│                                     │
│ ◆ June Monthly Test                │
│   Status: PUBLISHED ✓              │
│   Entries: 15                      │
│   Published: Jun 10, 10:30 AM      │
│   [  Edit  ] [  View  ] [  Delete ]│
│                                     │
│ ◇ Daily Test - Week 1              │
│   Status: DRAFT                    │
│   Entries: 8                       │
│   Created: Nov 1, 3:45 PM          │
│   [  Edit  ] [  Delete ]           │
│                                     │
│ ◇ Daily Test - Week 2              │
│   Status: DRAFT                    │
│   Entries: 0                       │
│   Created: Nov 1, 4:00 PM          │
│   [  Edit  ] [  Delete ]           │
│                                     │
└─────────────────────────────────────┘
```

**Screen: ExamTimetableCreatePage**

```
┌─────────────────────────────────────┐
│ Create New Timetable               │
├─────────────────────────────────────┤
│                                     │
│ Create from Calendar or Ad-hoc?    │
│                                     │
│ ◉ From Exam Calendar               │
│   [Select Calendar: June Monthly ▼]│
│                                     │
│ ◉ Ad-hoc (Daily Test)              │
│   Exam Name: [________________   ]│
│   Exam Number: [1] (Week 1)       │
│                                     │
│ Academic Year                      │
│ [2024-2025] (read-only)            │
│                                     │
│ [  Next  ] [  Cancel  ]            │
└─────────────────────────────────────┘
```

**Screen: ExamTimetableEditPage (Add Entries)**

```
┌────────────────────────────────────┐
│ June Monthly Test                  │
│ Status: DRAFT (can edit)           │
├────────────────────────────────────┤
│                                    │
│ Entries (15 total)                 │
│                                    │
│ [Grade] [Subject] [Section]        │
│ [Exam Date] [Time]     [Teachers]  │
│                                    │
│ Grade 5  Maths    A                │
│ Jun 15   9:00-10:30    Anita ✓    │
│          [Edit] [Delete]           │
│                                    │
│ Grade 5  English  A                │
│ Jun 16   9:00-10:00    Anita ✓    │
│          [Edit] [Delete]           │
│                                    │
│ Grade 5  Maths    B                │
│ Jun 15   10:00-11:30   Anita ✓    │
│ Priya ✓                            │
│          [Edit] [Delete]           │
│                                    │
│ Grade 6  Science  A                │
│ Jun 20   9:00-11:00    Rajesh ✗   │
│                        (No teacher!)
│          [Edit] [Delete]           │
│                                    │
│ [+ Add Entry]                      │
│                                    │
│ [  Publish  ] [  Cancel  ]         │
└────────────────────────────────────┘
```

**Screen: AddTimetableEntryPage**

```
┌────────────────────────────────────┐
│ Add Timetable Entry                │
├────────────────────────────────────┤
│                                    │
│ Grade                              │
│ [Grade 5 ▼]                        │
│                                    │
│ Section                            │
│ [Section A ▼]                      │
│                                    │
│ Subject                            │
│ [Maths ▼]                          │
│                                    │
│ Teachers Assigned                  │
│ ✓ Anita Sharma                     │
│ ✓ Priya Singh                      │
│ (2 teachers will get papers)       │
│                                    │
│ Exam Date                          │
│ [2024-06-15] [📅]                │
│                                    │
│ Start Time                         │
│ [09:00] [⏰]                       │
│                                    │
│ End Time                           │
│ [10:30] [⏰]                       │
│                                    │
│ Duration: 90 minutes (auto)        │
│                                    │
│ [  Add Entry  ] [  Cancel  ]       │
└────────────────────────────────────┘
```

---

### 3. Publish Timetable (Confirmation)

**Screen: PublishTimetableConfirmationPage**

```
┌─────────────────────────────────────┐
│ Publish Timetable?                 │
├─────────────────────────────────────┤
│                                     │
│ Exam: June Monthly Test            │
│ Status: DRAFT → PUBLISHED          │
│                                     │
│ Summary:                           │
│ • 15 entries                       │
│ • 8 subjects                       │
│ • 12 papers will be created        │
│                                     │
│ ⚠ WARNING: Cannot undo!            │
│ After publishing, teachers cannot  │
│ edit their assignments.            │
│                                     │
│ Entry Status Check:               │
│ ✓ All entries have teachers       │
│ ✓ No conflicts detected           │
│ ✓ Ready to publish                │
│                                     │
│ [  Yes, Publish  ] [  No, Cancel  ]│
└─────────────────────────────────────┘
```

---

### 4. Grade Sections Management

**Route**: `/admin/sections/manage`

**Screen: ManageGradeSectionsPage**

```
┌──────────────────────────────────┐
│ Manage Grade Sections            │
├──────────────────────────────────┤
│ Academic Year: 2024-2025         │
│ Last Updated: Nov 1, 2024        │
├──────────────────────────────────┤
│                                  │
│ Grade 1                          │
│ [Section A] [Delete]            │
│ [Section B] [Delete]            │
│ [+ Add Section]                 │
│                                  │
│ Grade 2                          │
│ [Section A] [Delete]            │
│ [+ Add Section]                 │
│                                  │
│ Grade 5                          │
│ [Section A] [Delete]            │
│ [Section B] [Delete]            │
│ [Section C] [Delete]            │
│ [+ Add Section]                 │
│                                  │
│ Grade 6                          │
│ [Section A] [Delete]            │
│ [Section B] [Delete]            │
│ [+ Add Section]                 │
│                                  │
│ [  Save Changes  ]              │
└──────────────────────────────────┘
```

**Component**:

```dart
class ManageGradeSectionsPage extends StatefulWidget {
  @override
  State<ManageGradeSectionsPage> createState() =>
      _ManageGradeSectionsPageState();
}

class _ManageGradeSectionsPageState extends State<ManageGradeSectionsPage> {
  // Map<GradeId, List<SectionName>>
  late Map<String, List<String>> _gradeSections;

  @override
  void initState() {
    super.initState();
    context.read<GradeSectionBloc>().add(const LoadGradeSections());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GradeSectionBloc, GradeSectionState>(
      builder: (context, state) {
        if (state is GradeSectionsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is GradeSectionsLoaded) {
          _gradeSections = state.sections;

          return Scaffold(
            body: ListView.builder(
              itemCount: _gradeSections.length,
              itemBuilder: (context, index) {
                final gradeId = _gradeSections.keys.elementAt(index);
                final sections = _gradeSections[gradeId]!;

                return _buildGradeCard(gradeId, sections);
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGradeCard(String gradeId, List<String> sections) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade $gradeId',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...sections.map((section) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(label: Text('Section $section')),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeSection(gradeId, section),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _addSection(gradeId),
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSection(String gradeId) {
    // Show dialog to add new section
    showDialog(
      context: context,
      builder: (context) {
        String sectionName = '';
        return AlertDialog(
          title: Text('Add Section to Grade $gradeId'),
          content: TextField(
            onChanged: (value) => sectionName = value,
            decoration: const InputDecoration(
              hintText: 'e.g., A, B, C',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _gradeSections[gradeId]?.add(sectionName);
                });
                context.pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeSection(String gradeId, String section) {
    setState(() {
      _gradeSections[gradeId]?.remove(section);
    });
  }
}
```

---

## State Management Structure

### BLoCs Needed

```
exam_timetable/
  presentation/
    bloc/
      exam_calendar_bloc.dart
      exam_timetable_bloc.dart
      grade_section_bloc.dart
  domain/
    usecases/
      create_exam_calendar_usecase.dart
      create_exam_timetable_usecase.dart
      publish_exam_timetable_usecase.dart
      load_grade_sections_usecase.dart
  data/
    repositories/
      exam_calendar_repository_impl.dart
      exam_timetable_repository_impl.dart
      grade_section_repository_impl.dart
```

### Events & States

```dart
// ExamCalendarBloc
abstract class ExamCalendarEvent extends Equatable {}
class LoadExamCalendars extends ExamCalendarEvent {}
class CreateExamCalendarEvent extends ExamCalendarEvent {
  final String examName;
  final String examType;
  // ... other fields
}

abstract class ExamCalendarState extends Equatable {}
class ExamCalendarLoading extends ExamCalendarState {}
class ExamCalendarsLoaded extends ExamCalendarState {
  final List<ExamCalendar> calendars;
}
class ExamCalendarCreateSuccess extends ExamCalendarState {}
class ExamCalendarError extends ExamCalendarState {
  final String message;
}
```

---

## Teacher Dashboard Integration

### Updated QuestionPaperCard

The existing paper cards need to show:
- ✅ Paper title (existing)
- ✅ Subject and Grade
- ✅ **NEW**: Section information
- ✅ **NEW**: Deadline status badge (on-time ✓ or overdue ⚠)
- ✅ **NEW**: Exam type badge

```
┌─────────────────────────┐
│ ✓ On Time      Monthly  │
├─────────────────────────┤
│ Maths - Grade 5-A      │
│                         │
│ Exam Date: Jun 15      │
│ Deadline: Jun 10 (1 day)│
│                         │
│ Progress: 5/50 Qs      │
│                         │
│ [  Edit Paper  ]       │
│ [  View Details  ]     │
└─────────────────────────┘
```

### Changes to Existing Code

**File**: `lib/features/paper_workflow/presentation/widgets/question_paper_card.dart`

```dart
class QuestionPaperCard extends StatelessWidget {
  final QuestionPaper paper;
  final VoidCallback onTap;

  // ... existing implementation ...

  @override
  Widget build(BuildContext context) {
    final isOverdue = paper.deadlineDate?.isBefore(DateTime.now()) ?? false;
    final daysUntilDeadline = paper.deadlineDate != null
        ? paper.deadlineDate!.difference(DateTime.now()).inDays
        : null;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status Badge (NEW)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOverdue ? '⚠ Overdue' : '✓ On Time',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Exam Type Badge (NEW)
                  Chip(
                    label: Text(paper.examType),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title with Section (NEW)
              Text(
                '${paper.subjectName} - ${paper.gradeId}-${paper.section ?? ""}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Deadline Info (NEW)
              if (daysUntilDeadline != null)
                Text(
                  'Deadline: $daysUntilDeadline days remaining',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              // ... rest of existing implementation ...
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Error Handling UI

### Validation Errors

When publishing timetable with unassigned entries:

```
┌──────────────────────────────────┐
│ ⚠ Cannot Publish                 │
├──────────────────────────────────┤
│                                  │
│ The following entries have no    │
│ teachers assigned:               │
│                                  │
│ • Grade 5-A, Science             │
│ • Grade 6-B, English             │
│                                  │
│ Action required:                 │
│ 1. Assign teachers to these      │
│    subjects and sections         │
│ 2. Return here to publish        │
│                                  │
│ [  Go Back  ]                   │
└──────────────────────────────────┘
```

---

## Loading States

### Paper Creation Spinner

When publishing large timetables:

```
┌──────────────────────────────────┐
│ Publishing Timetable...         │
├──────────────────────────────────┤
│                                  │
│        [↻ Loading Spinner]       │
│                                  │
│ Creating question papers...      │
│ 45/125 papers created           │
│                                  │
│ This may take a few moments.     │
│ Please don't close this window.  │
│                                  │
└──────────────────────────────────┘
```

---

## Responsive Design

### Mobile Constraints

- Exam timetable entry table converted to cards on mobile
- Dropdown menus for filters on mobile
- Bottom sheet for "Add Entry" instead of full page

### Tablet Layout

- Side-by-side admin panels
- Wider data tables with scrolling

---

## Accessibility Considerations

1. **Labels**: All form fields have proper labels
2. **Contrast**: Error messages use red (#FF3B30) with clear visibility
3. **Focus States**: Keyboard navigation support
4. **Descriptions**: Help text for complex selections (e.g., "Select sections you teach")

---

## Summary of UI Components

| Component | Purpose | Status |
|-----------|---------|--------|
| TeacherProfileSetupPage | Teacher selects (grade, subject, section) tuples | ✏️ REFACTOR |
| ExamCalendarListPage | Admin views/creates exam calendar | ✨ NEW |
| ExamCalendarCreatePage | Admin creates new exam | ✨ NEW |
| ExamTimetableListPage | Admin views timetables | ✨ NEW |
| ExamTimetableCreatePage | Admin creates new timetable | ✨ NEW |
| ExamTimetableEditPage | Admin adds/edits entries | ✨ NEW |
| AddTimetableEntryPage | Admin adds single entry | ✨ NEW |
| PublishConfirmationPage | Admin publishes with validation | ✨ NEW |
| ManageGradeSectionsPage | Admin defines sections per grade | ✨ NEW |
| QuestionPaperCard | Shows deadline/section (enhanced) | ✏️ ENHANCE |

Total: 10 screens/components (1 refactor, 2 enhancements, 7 new)

---

## Implementation Priority

1. **Phase 1** (Immediate): Refactor `TeacherProfileSetupPage`
2. **Phase 2** (Immediate): Create `ExamCalendarListPage`, `ExamCalendarCreatePage`
3. **Phase 3** (Immediate): Create `ManageGradeSectionsPage`
4. **Phase 4** (Core): Create `ExamTimetableCreatePage`, `ExamTimetableEditPage`, `AddTimetableEntryPage`
5. **Phase 5** (Core): Create `PublishConfirmationPage`
6. **Phase 6** (Polish): Enhance `QuestionPaperCard`
