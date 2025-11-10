# Exam Timetable Phase 1 - Implementation Checklist

## 🎯 Phase 1 Objective
By the end, admin can create and manage complete exam timetables (calendar → timetable → entries).

---

## ✅ Task 1: Database Migrations - COMPLETED

### Created Files
- [x] `supabase/migrations/20251107_create_exam_tables.sql` (350 lines)
- [x] `supabase/migrations/20251107_exam_tables_rls_policies.sql` (280 lines)
- [x] `supabase/migrations/EXAM_TIMETABLE_MIGRATION_GUIDE.md` (400 lines)
- [x] `TIMETABLE_PHASE1_DATABASE_SUMMARY.md` (summary & quick reference)

### What Was Created
- [x] `exam_calendar` table (template for exam periods)
- [x] `exam_timetables` table (specific year instance)
- [x] `exam_timetable_entries` table (individual exams)
- [x] Enhanced `question_papers` table with exam tracking
- [x] 13 indexes for optimal performance
- [x] 15 RLS policies for security
- [x] 3 triggers for auto timestamp updates

### Verification
- [ ] Apply migration files to Supabase
- [ ] Run verification queries from migration guide
- [ ] Confirm all 3 tables exist
- [ ] Confirm RLS is enabled (15 policies)
- [ ] Confirm question_papers has 2 new columns

---

## ⏳ Task 2: RLS Policies Setup - IN PROGRESS

### Status
✅ Already included in migration file `20251107_exam_tables_rls_policies.sql`

### Next Step
- [ ] After applying migrations, verify policies work correctly
- [ ] Test that non-admin users cannot insert/update/delete
- [ ] Test that users only see their tenant's data

---

## 🔄 Task 3: Create Domain Layer Entities - NEXT

### Entities to Create (in `lib/features/timetable/domain/entities/`)
- [ ] `exam_calendar_entity.dart` (ExamCalendarEntity)
- [ ] `exam_timetable_entity.dart` (ExamTimetableEntity)
- [ ] `exam_timetable_entry_entity.dart` (ExamTimetableEntryEntity)

### Fields for ExamCalendarEntity
```dart
id                      UUID
tenantId                UUID
examName                String
examType                String (enum: 'mid_term', 'final', 'unit_test')
monthNumber             int
plannedStartDate        DateTime
plannedEndDate          DateTime
paperSubmissionDeadline DateTime?
displayOrder            int
metadata                Map?
isActive                bool
createdAt               DateTime
updatedAt               DateTime
```

### Fields for ExamTimetableEntity
```dart
id                      UUID
tenantId                UUID
createdBy               UUID
examCalendarId          UUID?
examName                String
examType                String
examNumber              int?
academicYear            String (e.g., "2025-2026")
status                  String (enum: 'draft', 'published', 'archived')
publishedAt             DateTime?
paperSubmissionDeadline DateTime?
isActive                bool
metadata                Map?
createdAt               DateTime
updatedAt               DateTime
```

### Fields for ExamTimetableEntryEntity
```dart
id                      UUID
tenantId                UUID
examTimetableId         UUID
gradeId                 UUID
subjectId               UUID
gradeSectionId          UUID?
section                 String (A, B, C)
examDate                DateTime
startTime               DateTime
endTime                 DateTime
durationMinutes         int
assignedTeacherId       UUID?
assignmentStatus        String (enum: 'pending', 'acknowledged', 'in_progress')
isActive                bool
createdAt               DateTime
updatedAt               DateTime
```

### Requirements
- [ ] All entities implement `Equatable` for comparison
- [ ] All have `fromJson()` and `toJson()` methods
- [ ] All have proper `toString()` implementations
- [ ] Immutable (use `final` fields)
- [ ] Proper documentation comments

---

## 📁 Task 4: Data Layer - Datasources & Repositories - PENDING

### Files to Create
- [ ] `lib/features/timetable/data/datasources/exam_timetable_remote_data_source.dart`
  - Abstract class with method signatures
  - Implementation using Supabase client

- [ ] `lib/features/timetable/domain/repositories/exam_timetable_repository.dart`
  - Abstract repository interface

- [ ] `lib/features/timetable/data/repositories/exam_timetable_repository_impl.dart`
  - Concrete implementation with Either<Failure, T> pattern

### DataSource Methods to Implement
```dart
// Calendar operations
Future<List<ExamCalendarEntity>> getExamCalendars(String tenantId)
Future<ExamCalendarEntity> createExamCalendar(ExamCalendarEntity calendar)
Future<ExamCalendarEntity> updateExamCalendar(ExamCalendarEntity calendar)
Future<void> deleteExamCalendar(String id)

// Timetable operations
Future<List<ExamTimetableEntity>> getExamTimetables(String tenantId, String academicYear)
Future<ExamTimetableEntity> createExamTimetable(ExamTimetableEntity timetable)
Future<ExamTimetableEntity> updateExamTimetable(ExamTimetableEntity timetable)
Future<void> deleteExamTimetable(String id)
Future<void> publishExamTimetable(String timetableId)

// Entry operations
Future<List<ExamTimetableEntryEntity>> getExamTimetableEntries(String timetableId)
Future<ExamTimetableEntryEntity> addExamTimetableEntry(ExamTimetableEntryEntity entry)
Future<ExamTimetableEntryEntity> updateExamTimetableEntry(ExamTimetableEntryEntity entry)
Future<void> deleteExamTimetableEntry(String entryId)

// Validation
Future<List<ExamTimetableEntryEntity>> checkDuplicateEntries(
  String timetableId, String gradeId, String subjectId, DateTime date)
```

### Repository Pattern
- Wrap datasource calls with Either<Failure, T>
- Implement error handling
- Add logging for debugging
- Cache frequently accessed data if needed

---

## 🎯 Task 5: Domain Use Cases - PENDING

### Use Cases to Create (in `lib/features/timetable/domain/usecases/`)
- [ ] `create_exam_calendar_usecase.dart`
- [ ] `get_exam_calendars_usecase.dart`
- [ ] `create_exam_timetable_usecase.dart`
- [ ] `get_exam_timetables_usecase.dart`
- [ ] `add_exam_timetable_entry_usecase.dart`
- [ ] `update_exam_timetable_entry_usecase.dart`
- [ ] `delete_exam_timetable_entry_usecase.dart`
- [ ] `publish_exam_timetable_usecase.dart`
- [ ] `validate_exam_timetable_usecase.dart` (prevent duplicates)

### Each UseCase Should
- [ ] Have single responsibility
- [ ] Return Either<Failure, T>
- [ ] Have call() method
- [ ] Include input validation
- [ ] Include documentation

---

## 🔄 Task 6: BLoC State Management - PENDING

### Create ExamTimetableBloc

**File**: `lib/features/timetable/presentation/bloc/exam_timetable_bloc.dart`

**Events to Handle**:
- `LoadExamCalendars` → Load all calendars
- `CreateExamCalendar` → Create new calendar
- `LoadExamTimetables` → Load timetables for year
- `CreateExamTimetable` → Create new timetable
- `LoadTimetableEntries` → Load entries for timetable
- `AddTimetableEntry` → Add single entry
- `UpdateTimetableEntry` → Update entry
- `DeleteTimetableEntry` → Delete entry (soft)
- `PublishTimetable` → Publish timetable
- `ValidateTimetable` → Validate before publish

**States to Define**:
- `ExamTimetableInitial` - Initial state
- `ExamTimetableLoading` - Loading data
- `ExamCalendarsLoaded` - Calendars loaded
- `ExamTimetablesLoaded` - Timetables loaded
- `TimetableEntriesLoaded` - Entries loaded
- `EntryAdded` - Entry successfully added
- `EntryUpdated` - Entry successfully updated
- `EntryDeleted` - Entry successfully deleted
- `TimetablePublished` - Timetable published
- `ValidationSuccess` - Validation passed
- `ExamTimetableError` - Error occurred

**Features**:
- [ ] Multi-step form support (Step 1 → Step 2 → Step 3)
- [ ] Cache timetable data between steps
- [ ] Validate duplicate entries on add
- [ ] Track publication state
- [ ] Error recovery

---

## 🎨 Task 7: UI Layer - Pages & Widgets - PENDING

### 7.1 Exam Calendar Setup Page

**File**: `lib/features/timetable/presentation/pages/exam_calendar_page.dart`

**Features**:
- [ ] List view of existing calendars
- [ ] "Create New Calendar" floating action button
- [ ] Modal/dialog for calendar creation form:
  - [ ] Exam name (text input)
  - [ ] Exam type (dropdown: mid_term, final, unit_test)
  - [ ] Month number (dropdown: 1-12)
  - [ ] Planned start date (date picker)
  - [ ] Planned end date (date picker)
  - [ ] Paper submission deadline (date picker)
  - [ ] Display order (number input)
- [ ] Edit existing calendars
- [ ] Delete calendars
- [ ] Show/hide inactive calendars toggle
- [ ] Loading states
- [ ] Error messages

---

### 7.2 Exam Timetable Creation Wizard

**File**: `lib/features/timetable/presentation/pages/exam_timetable_wizard_page.dart`

#### Step 1: Basic Info
- [ ] Select exam calendar (dropdown/list)
- [ ] OR create inline exam info
- [ ] Academic year (text/picker)
- [ ] Paper submission deadline (with calendar deadline default)
- [ ] "Next" button

#### Step 2: Add Exam Entries (Repeatable)
- [ ] Grade selector (dropdown from grades table)
- [ ] Subject selector (filtered by selected grade, from subjects)
- [ ] Exam date (date picker)
- [ ] Start time (time picker)
- [ ] End time (time picker)
- [ ] Duration (auto-calculated, editable)
- [ ] Section (dropdown: A, B, C from grade_sections)
- [ ] "Add Entry" button
- [ ] Display table of added entries with columns:
  - Grade | Subject | Date | Time | Duration | Section
  - Edit/Delete actions per row
- [ ] "Add Another" or "Next" button

#### Step 3: Review & Publish
- [ ] Summary table of all entries
- [ ] Validation checks:
  - [ ] No duplicate grade+subject+date ✓
  - [ ] All required fields filled ✓
  - [ ] Date range makes sense (warning only)
- [ ] "Save as Draft" button
- [ ] "Publish Timetable" button
- [ ] Success message with timetable ID

**Features**:
- [ ] Multi-step navigation (back/next)
- [ ] Progress indicator
- [ ] Unsaved changes warning
- [ ] Form validation feedback
- [ ] Real-time duplicate checking

---

### 7.3 Timetable Management Page

**File**: `lib/features/timetable/presentation/pages/exam_timetable_management_page.dart`

**Features**:
- [ ] List all timetables
- [ ] Filter by:
  - [ ] Academic year (dropdown)
  - [ ] Status (draft/published/archived)
  - [ ] Exam type
- [ ] Card view showing:
  - [ ] Exam name & type
  - [ ] Status badge (draft/published/archived)
  - [ ] Date range
  - [ ] Total entries count
  - [ ] Created by & date
- [ ] Actions per card:
  - [ ] View/Edit (if draft)
  - [ ] Delete (if draft, soft delete)
  - [ ] View Details (if published)
  - [ ] Duplicate (copy structure)
  - [ ] Publish (if draft)
  - [ ] Archive (if published)
- [ ] Create new timetable button → goes to wizard
- [ ] Search functionality
- [ ] Sort options

---

## ✅ Task 8: Validation & Error Handling - PENDING

### Validations to Implement
- [ ] Duplicate entry check (grade+subject+date unique)
- [ ] Date range validation (start ≤ end)
- [ ] Time range validation (start < end)
- [ ] Duration calculation verification
- [ ] Required field validation
- [ ] Academic year format validation (YYYY-YYYY)
- [ ] Exam type enum validation
- [ ] Assignment status enum validation

### Error Handling
- [ ] Database constraint violations → user-friendly messages
- [ ] Network errors → retry logic
- [ ] Validation errors → field-level feedback
- [ ] Permission errors → admin-only access messages
- [ ] Soft delete handling → cannot modify inactive entries

### User Feedback
- [ ] Loading indicators for all async operations
- [ ] Success snackbars after creation/update/delete
- [ ] Error snackbars with actionable messages
- [ ] Toast notifications for important events

---

## 🧪 Task 9: Unit Tests - PENDING

### Test Files to Create
- [ ] `test/features/timetable/domain/usecases/*_test.dart` (9 use case tests)
- [ ] `test/features/timetable/presentation/bloc/exam_timetable_bloc_test.dart`
- [ ] `test/features/timetable/data/repositories/exam_timetable_repository_impl_test.dart`

### Test Coverage Goals
- [ ] Use cases: 100% coverage
- [ ] BLoC events/states: All paths tested
- [ ] Repository: All methods tested with mocks
- [ ] Error scenarios: Failures handled correctly

---

## 🚀 Task 10: End-to-End Testing - PENDING

### Manual Testing Scenarios

**Scenario 1: Create Complete Timetable**
- [ ] Create exam calendar
- [ ] Create timetable from calendar
- [ ] Add 10+ entries with different grades/subjects
- [ ] Verify no duplicates allowed
- [ ] Publish timetable
- [ ] Verify status changes to "published"
- [ ] Verify entries visible on management page

**Scenario 2: Edit & Update**
- [ ] Create draft timetable
- [ ] Edit entry details
- [ ] Add/remove entries
- [ ] Save changes
- [ ] Reload page
- [ ] Verify changes persisted

**Scenario 3: Error Handling**
- [ ] Try to create duplicate entry → error message
- [ ] Try to add entry with missing field → validation error
- [ ] Try to delete as non-admin → permission error
- [ ] Disconnect internet → graceful error

**Scenario 4: Data Persistence**
- [ ] Create timetable with 5 entries
- [ ] Log out and log back in
- [ ] Navigate to management page
- [ ] Verify timetable and entries still exist
- [ ] Verify soft-deleted entries are hidden

---

## 📊 Success Criteria Checklist

At the end of Phase 1, verify:

- [ ] **Database**: All 3 tables exist with correct schema
- [ ] **RLS**: 15 policies enabled, tenants isolated
- [ ] **Entities**: All 3 entities created with proper serialization
- [ ] **Repositories**: CRUD operations working
- [ ] **Use Cases**: All 9 use cases implemented
- [ ] **BLoC**: All events handled, all states defined
- [ ] **Calendar Page**: Create, view, edit calendars
- [ ] **Wizard Page**: 3-step wizard works, validates duplicates
- [ ] **Management Page**: List, filter, manage timetables
- [ ] **Validation**: Duplicate checking works
- [ ] **Error Handling**: User-friendly error messages
- [ ] **Tests**: 80%+ code coverage
- [ ] **E2E**: Complete flow works end-to-end
- [ ] **Data Persistence**: Data survives page reloads
- [ ] **RLS Working**: Non-admin users cannot modify

---

## 🎯 Expected Final State

### Admin Can:
✅ Create exam calendar (template)
✅ Create exam timetable (for specific year)
✅ Add 10+ exam entries to timetable
✅ Edit any entry (if still in draft)
✅ Delete entries (soft delete)
✅ Publish timetable (status: draft → published)
✅ View all timetables (filtered by year/status)
✅ Cannot create duplicate exams (enforced at DB level)
✅ Cannot modify published timetables (Phase 2)

### System:
✅ Tracks who created what and when
✅ Enforces data consistency with constraints
✅ Isolates tenant data with RLS
✅ Provides user feedback for all operations
✅ Handles errors gracefully
✅ Maintains audit trail

---

## 📝 Notes

- Task 1 & 2 are **COMPLETE** ✅
- Tasks 3-10 are **PENDING** ⏳
- Total estimated effort: 16-24 hours
- Proceed task-by-task in order
- Update this checklist as you progress

---

**Last Updated**: 2025-11-07
**Current Task**: 1 & 2 (Database & RLS) - COMPLETE
**Next Task**: 3 (Domain Entities)
**Phase 1 Progress**: 17% (2/12 tasks complete)
