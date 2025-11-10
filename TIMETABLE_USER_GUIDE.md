# Exam Timetable - User & Developer Guide

## Overview
The exam timetable system allows admins to create, manage, and publish exam schedules. The system includes a 5-step wizard for creation and a management dashboard for viewing and editing timetables.

---

## How to Create a Timetable (User Workflow)

### Step 1: Navigate to Timetable List
1. Login as an **Admin** user
2. From the main admin dashboard, navigate to: `/admin/exams/timetables`
3. Click the **"Create New Timetable"** button (blue button with + icon)

### Step 2: Select Exam Calendar (Step 1 of Wizard)
The wizard will open with a list of available exam calendars.

**What you see:**
- Calendar name and academic year
- Number of exam dates in the calendar
- Quick info about calendar details

**What you do:**
- Select one calendar by tapping on it (blue border appears)
- Click **Next** to proceed

**Calendar info includes:**
- Name: E.g., "Term 1 Final Exams"
- Academic Year: E.g., "2024-2025"
- Exam start/end dates
- Status indicator

### Step 3: Enter Timetable Information (Step 2 of Wizard)
Fill in the basic details about the exam timetable.

**Fields to complete:**
1. **Exam Name** (required)
   - Example: "Mathematics Final Exam"
   - Validation: Cannot be empty

2. **Exam Type** (required, dropdown)
   - Options: Final, Midterm, Quiz, Practice, Diagnostic, Supplementary
   - Select the appropriate type

3. **Academic Year** (required, dropdown)
   - Format: YYYY-YYYY (e.g., 2024-2025)
   - Must match calendar's academic year
   - Validation: Must be valid format and must span exactly 1 year

**Summary display:**
- Shows all entered data at bottom of form
- Updates in real-time as you type

**Navigation:**
- Click **Next** to proceed
- Click **Back** to edit calendar selection

### Step 4: Select Grades & Sections (Step 3 of Wizard)
Choose which grades and sections will participate in this exam.

**What you see:**
- List of available grades (e.g., Grade 9, 10, 11, 12)
- For each grade, list of available sections (e.g., A, B, C)

**What you do:**
- Tap on individual sections to toggle them (checkbox style)
- Or tap on a grade header to select/deselect all sections in that grade

**Example:**
```
Grade 10
  ☑ Section A  (selected)
  ☐ Section B  (not selected)
  ☑ Section C  (selected)

Grade 11
  ☑ Section A  (selected)
  ☐ Section B  (not selected)
```

**Counter display:**
- Shows "X grade-section combinations selected"
- Example: "6 combinations selected" (Grade 10 A+C, Grade 11 A, etc.)

**Navigation:**
- Click **Next** to proceed to entry creation
- Click **Back** to change exam info

### Step 5: Add Exam Entries (Step 4 of Wizard)
Create individual exam time slots for each grade-section combination.

**Entry fields:**
1. **Grade** (required, dropdown)
   - Shows grades from previous step

2. **Subject** (required, dropdown)
   - List of available subjects

3. **Section** (required, dropdown)
   - Shows sections for selected grade

4. **Exam Date** (required, date picker)
   - Must be within calendar dates
   - Cannot be in the past
   - Tap calendar icon to pick date

5. **Start Time** (required, time picker)
   - Format: HH:MM (24-hour)
   - Example: 09:00, 14:30
   - Tap clock icon to pick time

6. **End Time** (required, time picker)
   - Must be after start time
   - Example: 11:00, 16:30

**Workflow:**
1. Fill in all fields above
2. Click **"Add Entry"** button
3. Entry appears in list below with:
   - Date
   - Time range
   - Duration (calculated from start-end)
4. Continue adding more entries as needed

**Entry list display:**
- Shows all added entries
- Each entry shows: Subject, Date, Time, Duration
- Delete button (trash icon) to remove entries

**Validation:**
- All fields must be filled
- End time must be after start time
- Exam date cannot be in past
- Duplicate entries (same grade+subject+section+date) not allowed
- No time conflicts (same grade can't have overlapping exams on same day)

**Navigation:**
- Click **Next** to review all entries
- Click **Back** to change grades/sections

### Step 6: Review & Publish (Step 5 of Wizard)
Final review before publishing the timetable.

**Summary displays:**
- Timetable info: Name, Type, Academic Year, Calendar
- Grades & Sections: All selected combinations
- Exam Entries: List grouped by date
  - Shows Subject, Grade, Section, Time, Duration for each
- Entry count and grade count totals

**What you do:**
1. Review all information
2. Click **"Publish Timetable"** button
   - Triggers validation of all entries
   - If errors found, dialog shows all issues
   - Must fix errors before publishing
3. On success:
   - Timetable created in database
   - Status set to "Published"
   - Returns to timetable list
   - Success message shown

**If validation fails:**
- Error dialog appears showing all issues
- Grouped by category:
  - Time Issues
  - Duplicate Entries
  - Conflicts
  - Date Issues
  - Missing Information
- Fix errors in previous steps
- Click "Got It" to dismiss
- Step back and make changes
- Return to review step

**Navigation:**
- Click **Back** to edit entries
- Click **"Publish Timetable"** to submit
- Close button (X) to cancel wizard

---

## How to Access & Manage Timetables (User Workflow)

### View Timetable List
**URL:** `/admin/exams/timetables`
**Access:** Admin dashboard → Exams → Timetables

**List display shows:**
- All timetables with their details
- Filter by status (All, Draft, Published, Archived)

**Status meanings:**
- 🟠 **Draft**: Editable, not yet published
- 🟢 **Published**: Finalized, read-only (can be archived)
- 🔘 **Archived**: Completed, read-only

### Filter Timetables
The list page has a filter bar at the top:

**Filter options:**
- **All**: Show all timetables (selected by default)
- **Draft**: Only unpublished timetables
- **Published**: Only published timetables
- **Archived**: Only archived timetables

**How to filter:**
1. Tap on a filter chip
2. List updates instantly to show only matching timetables

### View Timetable Details
**From list page:**
1. Tap on any timetable card
2. Opens detail page with two tabs:

**Tab 1 - Information:**
- Basic Info: Name, Type, Year, Exam Number
- Status: Current status, active flag, publish date
- Calendar: Link to associated calendar
- Additional Info: Custom metadata
- Audit Info: Creator, creation/update dates, ID

**Tab 2 - Entries:**
- All exam entries grouped by date
- For each entry shows:
  - Subject name
  - Grade & Section
  - Exam time range
  - Duration (hours or minutes)
- Sorted chronologically by exam date

### Perform Actions on Timetables

**From list page, each timetable card has action buttons:**

#### For Draft Timetables 🟠
- **View**: Open detail page
- **Edit**: Open edit page (placeholder - to be implemented)
- **Publish**: Convert to Published status
  - Shows confirmation dialog
  - Validates all entries
  - If valid, publishes immediately
  - If invalid, shows error dialog
- **Delete**: Remove timetable permanently
  - Shows confirmation dialog
  - Cannot be undone

#### For Published Timetables 🟢
- **View**: Open detail page
- **Archive**: Convert to Archived status
  - Shows confirmation dialog
  - Marks timetable as completed
  - Cannot be edited after archiving
  - Cannot be undone

#### For Archived Timetables 🔘
- **View**: Open detail page (read-only)
- No other actions available

### Publish a Timetable
**From draft timetable:**
1. Tap **"Publish"** button
2. Confirmation dialog appears: "Are you sure you want to publish this timetable?"
3. Click **"Publish"**
4. System validates all entries:
   - No duplicates
   - No time conflicts
   - All required fields complete
   - Dates not in past
5. If valid:
   - Timetable status changes to Published (🟢)
   - Success message shown
   - List refreshes
6. If invalid:
   - Error dialog shows all validation issues
   - Click "Got It" to dismiss
   - Return to list and edit timetable first

### Archive a Timetable
**From published timetable:**
1. Tap **"Archive"** button
2. Confirmation dialog appears: "Archive this timetable?"
3. Click **"Archive"**
4. Timetable status changes to Archived (🔘)
5. Success message shown
6. List refreshes

### Delete a Timetable
**From draft timetable only:**
1. Tap **"Delete"** button
2. Confirmation dialog appears: "Delete this timetable? This action cannot be undone."
3. Click **"Delete"**
4. Timetable removed from database
5. Success message shown
6. List refreshes

---

## Developer Integration Guide

### Routes Configuration

**Routes defined in** `lib/core/presentation/routes/app_routes.dart`:

```dart
static const String examTimetableList = '/admin/exams/timetables';
static const String examTimetableCreate = '/admin/exams/timetables/create';
static const String examTimetableEdit = '/admin/exams/timetables/edit';
```

**Route setup in** `lib/core/presentation/routes/app_router.dart`:

```dart
// List page
GoRoute(
  path: AppRoutes.examTimetableList,
  builder: (context, state) {
    final tenantId = _getTenantIdFromAuth(context);
    final academicYear = state.uri.queryParameters['academicYear'] ?? '2024-2025';
    return BlocProvider(
      create: (_) => sl<ExamTimetableBloc>(),
      child: ExamTimetableListPage(
        tenantId: tenantId,
        academicYear: academicYear,
      ),
    );
  },
),

// Create page (wizard)
GoRoute(
  path: AppRoutes.examTimetableCreate,
  builder: (context, state) {
    final tenantId = _getTenantIdFromAuth(context);
    final userId = _getUserIdFromAuth(context);
    return BlocProvider(
      create: (_) => sl<ExamTimetableBloc>(),
      child: ExamTimetableCreateWizardPage(
        tenantId: tenantId,
        createdBy: userId,
      ),
    );
  },
),
```

### Navigation in Code

**Navigate to timetable list:**
```dart
context.go(AppRoutes.examTimetableList);
```

**Navigate to create timetable:**
```dart
context.go(AppRoutes.examTimetableCreate);
```

**Navigate to timetable detail:**
```dart
context.go('${AppRoutes.examTimetableList}/$timetableId');
```

### BLoC Integration

**Events that trigger timetable operations:**

```dart
// Load all timetables
context.read<ExamTimetableBloc>().add(GetExamTimetablesEvent());

// Get single timetable by ID
context.read<ExamTimetableBloc>().add(
  GetExamTimetableByIdEvent(timetableId: timetableId),
);

// Get entries for timetable
context.read<ExamTimetableBloc>().add(
  GetExamTimetableEntriesEvent(timetableId: timetableId),
);

// Create new timetable
context.read<ExamTimetableBloc>().add(
  CreateExamTimetableEvent(
    timetable: timetable,
    entries: entries,
  ),
);

// Publish timetable
context.read<ExamTimetableBloc>().add(
  PublishExamTimetableEvent(timetableId: timetableId),
);

// Archive timetable
context.read<ExamTimetableBloc>().add(
  ArchiveExamTimetableEvent(timetableId: timetableId),
);

// Delete timetable
context.read<ExamTimetableBloc>().add(
  DeleteExamTimetableEvent(timetableId: timetableId),
);
```

**States to handle:**

```dart
if (state is ExamTimetableLoading) {
  // Show loading spinner
}

if (state is ExamTimetablesLoaded) {
  // Display list of timetables
  final timetables = state.timetables;
}

if (state is ExamTimetableLoaded) {
  // Display single timetable details
  final timetable = state.timetable;
}

if (state is ExamTimetableEntriesLoaded) {
  // Display entries
  final entries = state.entries;
}

if (state is ExamTimetablePublished) {
  // Show success, refresh list
  context.showSuccessMessage('Timetable published successfully!');
}

if (state is ExamTimetableArchived) {
  // Show success, refresh list
  context.showSuccessMessage('Timetable archived successfully!');
}

if (state is ExamTimetableDeleted) {
  // Show success, refresh list
  context.showSuccessMessage('Timetable deleted successfully!');
}

if (state is ExamTimetableError) {
  // Show error dialog
  context.showErrorMessage(state.message);
}
```

### Validation in Code

**Using validation service:**

```dart
final validationService = TimetableValidationService();

// Validate before publishing
final result = validationService.validateTimetableForPublishing(
  timetable,
  entries,
);

if (result.isValid) {
  // Proceed with publishing
} else {
  // Show errors to user
  ValidationErrorDialog.show(
    context,
    errors: result.errors,
  );
}

// Real-time form validation
final entryValidation = validationService.validateEntryInput(
  gradeId: gradeId,
  subjectId: subjectId,
  section: section,
  examDate: examDate,
  startTime: startTime,
  endTime: endTime,
);

if (entryValidation.isValid) {
  // Enable save button
} else {
  // Show field errors
  context.showValidationError(entryValidation.errors);
}
```

### Error Handling

**Using error handler utilities:**

```dart
import 'package:papercraft/features/timetable/presentation/utils/error_handler.dart';

// Convert error to user message
final message = ErrorHandler.getErrorMessage(error);

// Get error severity for styling
final severity = ErrorHandler.getSeverity(error);
// Returns: ErrorSeverity.info, warning, error, or critical

// Check if error is recoverable
if (ErrorHandler.isRecoverable(error)) {
  showRetryButton();
}

// Get suggested actions for error
final suggestions = ErrorSuggestions.getSuggestions(error);
// Returns list of ErrorAction buttons

// Format validation errors by category
final grouped = ValidationErrorFormatter.groupErrors(errors);
// Returns: Map<String, List<String>>
// Keys: "Time Issues", "Duplicate Entries", "Conflicts", etc.

// Show snackbar with error
context.showErrorMessage(
  ErrorHandler.getErrorMessage(error),
);

// Show success message
context.showSuccessMessage('Timetable published!');

// Show validation errors in dialog
context.showValidationError(validationResult.errors);
```

### UI Components

**Pages:**
- `exam_timetable_list_page.dart`: List and filter page
- `exam_timetable_create_wizard_page.dart`: 5-step creation wizard
- `exam_timetable_detail_page.dart`: Detail view with tabs

**Wizard steps:**
- `timetable_wizard_step1_calendar.dart`: Calendar selection
- `timetable_wizard_step2_info.dart`: Timetable info form
- `timetable_wizard_step3_grades.dart`: Grade/section selection
- `timetable_wizard_step4_entries.dart`: Entry creation
- `timetable_wizard_step5_review.dart`: Final review

**Widgets:**
- `timetable_list_item.dart`: Individual timetable card
- `timetable_detail_info_tab.dart`: Info tab content
- `timetable_detail_entries_tab.dart`: Entries tab content
- `validation_error_dialog.dart`: Error display dialog

**Utilities:**
- `error_handler.dart`: Error message mapping
- `timetable_validation_service.dart`: Validation rules

---

## Data Model

### ExamTimetableEntity
```dart
class ExamTimetableEntity {
  final String id;
  final String tenantId;
  final String examName;
  final String examType; // Final, Midterm, Quiz, etc.
  final String academicYear; // 2024-2025
  final String? examCalendarId;
  final String status; // draft, published, archived
  final bool isActive;
  final DateTime? publishedAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // ... rest of implementation
}
```

### ExamTimetableEntryEntity
```dart
class ExamTimetableEntryEntity {
  final String id;
  final String timetableId;
  final String gradeId;
  final String subjectId;
  final String section;
  final DateTime examDate;
  final Duration startTime;
  final Duration endTime;
  final int durationMinutes;

  // Computed properties:
  // - examDateDisplay: Formatted date string
  // - startTimeDisplay: Formatted time (HH:MM)
  // - endTimeDisplay: Formatted time (HH:MM)
  // - hasValidTimeRange: startTime < endTime
}
```

---

## Common Tasks

### Task: Add a timetable programmatically

```dart
final timetable = ExamTimetableEntity(
  id: 'timetable_001',
  tenantId: tenantId,
  examName: 'Final Exams 2024',
  examType: 'Final',
  academicYear: '2024-2025',
  examCalendarId: calendarId,
  status: 'draft',
  isActive: true,
  createdBy: userId,
  createdAt: DateTime.now(),
);

final entries = [
  ExamTimetableEntryEntity(
    id: 'entry_001',
    timetableId: timetable.id,
    gradeId: '10',
    subjectId: 'Mathematics',
    section: 'A',
    examDate: DateTime(2024, 11, 15),
    startTime: Duration(hours: 9),
    endTime: Duration(hours: 11),
    durationMinutes: 120,
  ),
];

context.read<ExamTimetableBloc>().add(
  CreateExamTimetableEvent(
    timetable: timetable,
    entries: entries,
  ),
);
```

### Task: Validate entries before save

```dart
final validationService = TimetableValidationService();
final result = validationService.validateTimetableForPublishing(
  timetable,
  entries,
);

if (result.isValid) {
  // Proceed with save
  saveTimetable(timetable, entries);
} else {
  // Show errors
  showDialog(
    context: context,
    builder: (context) => ValidationErrorDialog(
      errors: result.errors,
      onDismiss: () => Navigator.pop(context),
    ),
  );
}
```

### Task: Handle publish with validation

```dart
ElevatedButton(
  onPressed: () {
    final result = validationService.validateTimetableForPublishing(
      timetable,
      entries,
    );

    if (result.isValid) {
      context.read<ExamTimetableBloc>().add(
        PublishExamTimetableEvent(timetableId: timetable.id),
      );
    } else {
      ValidationErrorDialog.show(
        context,
        errors: result.errors,
      );
    }
  },
  child: const Text('Publish'),
)
```

---

## Troubleshooting

### Timetable list showing no items
**Cause:** No timetables created or filters not matching
**Solution:**
1. Verify timetables exist in database
2. Check filter - ensure "All" is selected
3. Verify tenant_id is correct
4. Check RLS policies allow read access

### Validation errors on publish
**Cause:** Timetable violates one or more rules
**Solution:**
1. Review error dialog for specific issues
2. Go back to edit entries
3. Fix issues (change times, remove duplicates)
4. Return to review and try again

### Routes not working
**Cause:** Routes not registered in app_router.dart
**Solution:**
1. Verify routes exist in app_routes.dart
2. Verify GoRoute configured in _buildRoutes()
3. Verify BLoC provider initialized
4. Check navigation context is correct

### BLoC events not triggering
**Cause:** BLoC not in context or events not dispatched
**Solution:**
1. Verify BlocProvider wraps page
2. Check event is being added to BLoC
3. Verify BLoC listeners are setup
4. Check state is being emitted

---

## Next Steps

### Planned Features
- [ ] Edit existing published timetables
- [ ] Bulk import from CSV/Excel
- [ ] Export to PDF/Print
- [ ] Teacher conflict detection
- [ ] Room availability validation
- [ ] Student attendance tracking
- [ ] Search and advanced filtering
- [ ] Scheduling optimization
- [ ] Email notifications
- [ ] Mobile app synchronization

### Current Limitations
- Edit timetable page is placeholder (redirects to create)
- No bulk operations (select multiple)
- No sorting/search on list
- No export functionality
- No calendar view (only list)
- No student-specific schedules

