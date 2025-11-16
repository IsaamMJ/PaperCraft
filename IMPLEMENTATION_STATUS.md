# Question Paper Auto-Assignment Feature - Implementation Status

## ✅ COMPLETED COMPONENTS

### 1. Database Migration
- **File**: `supabase/migrations/20251116_add_auto_assignment_support.sql`
- **Changes**:
  - Added `exam_timetable_entry_id` column to `question_papers` table (nullable UUID)
  - Created foreign key constraint to `exam_timetable_entries`
  - Modified `paper_sections` constraint to allow empty arrays when `status='draft'`
  - Added indexes for performance

### 2. Entity Updates
- **File**: `lib/features/paper_workflow/domain/entities/question_paper_entity.dart`
- **Changes**:
  - Added `examTimetableEntryId` field (links to exam timetable entry)
  - Added `section` field (pre-filled for auto-assigned papers)
  - Updated constructor, copyWith method, and props list

### 3. Role Management
- **File**: `lib/features/authentication/domain/entities/user_role.dart`
- **Changes**:
  - Added `director` role to UserRole enum
  - Updated `fromString()`, `value` getter, and `displayName` getter
  - Director can view reports and manage assessments

### 4. Auto-Assignment Logic
- **Usecase**: `lib/features/paper_workflow/domain/usecases/auto_assign_question_papers_usecase.dart`
  - New usecase for auto-assigning papers when timetable is published
  - Takes timetable entries with teacher assignments as input
  - Returns list of created question papers

- **Repository Implementation**: `lib/features/paper_workflow/data/repositories/question_paper_repository_impl.dart`
  - Implemented `autoAssignPapersForTimetable()` method
  - Creates blank draft papers for each teacher
  - Pre-fills metadata: grade_id, subject_id, section, exam_date, exam_type, exam_number
  - Auto-generates paper title: "Grade 2 Mathematics - 21 Nov 2025"
  - Links each paper to timetable entry via `exam_timetable_entry_id`

- **Repository Interface**: `lib/features/paper_workflow/domain/repositories/question_paper_repository.dart`
  - Added abstract method `autoAssignPapersForTimetable()`

### 5. Marks Validation
- **File**: `lib/features/paper_workflow/domain/usecases/submit_paper_usecase.dart`
  - Added comprehensive documentation about marks validation
  - Explains how validation integrates with exam calendar marks_config

- **Repository Implementation**: `lib/features/paper_workflow/data/repositories/question_paper_repository_impl.dart`
  - Added marks validation check in `submitPaper()` method
  - Calls `_validatePaperMarksAgainstExamCalendar()` for auto-assigned papers
  - Placeholder implementation with TODO for full validation
  - Full validation requires:
    1. Fetch exam_timetable_entry via exam_timetable_entry_id
    2. Get associated exam_calendar
    3. Extract marks_config for grade range
    4. Compare paper.totalMarks with max_marks

## ✅ COMPLETED (Continued)

### 6. Publish + Auto-Assign Orchestration
- **File**: `lib/features/timetable/domain/usecases/publish_timetable_and_auto_assign_papers_usecase.dart`
- **Class**: `PublishTimetableAndAutoAssignPapersUsecase`
- **Flow**:
  1. Calls `PublishExamTimetableUsecase` to publish timetable
  2. On success, fetches all exam timetable entries
  3. For each entry, queries `TeacherSubjectRepository` to get assigned teachers
  4. Fetches teacher names from `UserRepository`
  5. Builds timetable entries data structure with teacher info
  6. Calls `AutoAssignQuestionPapersUsecase` with complete data
  7. Returns result with paper count
- **Error Handling**: If auto-assignment fails, timetable still published (no rollback)
- **Teachers Involved**: Uses teacher_subjects table to find who teaches each grade/section/subject

## 🔄 IN PROGRESS / PENDING

### Integration with Dependency Injection & BLoC
- **Work Needed**: Register `PublishTimetableAndAutoAssignPapersUsecase` in DI container
- **Location**: `lib/core/infrastructure/di/injection_container.dart`
- **Then**: Update `ExamTimetableBloc` to use new orchestration usecase instead of plain publish
- **Result**: Single publish event now includes auto-assignment automatically

### Teacher Dashboard Updates
- **Work Needed**: Show auto-assigned vs manual papers
- **Filter Logic**:
  - Auto-assigned: `WHERE exam_timetable_entry_id IS NOT NULL`
  - Manual (legacy): `WHERE exam_timetable_entry_id IS NULL`
- **UI Changes**:
  - Add badge/indicator showing "Auto-assigned from Timetable"
  - Show pre-filled metadata
  - Highlight that metadata is read-only for auto-assigned papers

### Backward Compatibility
- **Existing 25 Papers**: Untouched - have `exam_timetable_entry_id = NULL`
- **New Papers**: All auto-assigned papers have `exam_timetable_entry_id` populated
- **Teacher Creation Path**: Unaffected - teachers can still create papers manually
- **Testing**: Verify both old and new papers work correctly

## 📋 NEXT STEPS

1. **Run Migration**: Execute the Supabase migration to add the column
   ```bash
   supabase db push
   ```

2. **Implement Auto-Assignment Integration**:
   - Update `PublishExamTimetableEvent` handler in `exam_timetable_bloc.dart`
   - After timetable publication, fetch all entries and teacher assignments
   - Call `AutoAssignQuestionPapersUsecase`

3. **Update Teacher Dashboard**:
   - Filter papers by `exam_timetable_entry_id`
   - Show visual indicators for auto-assigned papers
   - Display pre-filled metadata

4. **Complete Marks Validation**:
   - Implement `_validatePaperMarksAgainstExamCalendar()` fully
   - Create datasource methods to fetch exam_calendar marks_config
   - Add comprehensive validation logic

5. **Manual Migration of 25 Papers** (Optional):
   - Create a one-time admin tool for teachers to link existing papers
   - Or leave them orphaned and let new workflow handle future papers

## 🔑 KEY DESIGN DECISIONS

1. **Create 2 Papers for Collaborative Teaching**: Not 1 shared paper
   - Each teacher gets their own paper
   - Admin can delete duplicate if they want one shared paper

2. **Auto-Assignment on Publish**: Not on timetable creation
   - Timetable must be finalized before papers are assigned
   - Teachers don't see incomplete assignments

3. **Nullable exam_timetable_entry_id**: For backward compatibility
   - Existing papers: NULL (not affected)
   - New papers: Always populated

4. **Marks Validation at Submit Time**: Not at creation
   - Placeholder implementation allows development
   - Full validation can be added without breaking existing code

## 🧪 TESTING CHECKLIST

- [ ] Database migration applies successfully
- [ ] New papers auto-assign when timetable is published
- [ ] Existing 25 papers still load and work
- [ ] Teachers can edit auto-assigned papers
- [ ] Teachers can still create papers manually
- [ ] Paper submission works for both auto-assigned and manual papers
- [ ] Dashboard shows both types of papers correctly
- [ ] Marks validation works (placeholder for now)
- [ ] Director role has appropriate permissions
