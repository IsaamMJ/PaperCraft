# Exam Timetable System - Implementation Roadmap

## Executive Summary

This document provides a detailed implementation roadmap for the Exam Timetable System, including timelines, dependencies, resource allocation, and deployment strategy.

**Total Estimated Timeline**: 6-8 weeks (full-time development)
**Risk Level**: Medium (complex business logic, high data integrity requirements)
**Dependencies**: Existing authentication, notification, and question paper systems

---

## Phase Overview

```
Phase 1: Foundation (1.5 weeks) ────→ Phase 2: Backend (2.5 weeks) ────→ Phase 3: Frontend (2 weeks) ────→ Phase 4: Integration & Testing (1 week) ────→ Phase 5: Deployment (0.5 weeks)
```

---

## Phase 1: Foundation & Database Preparation (Week 1-1.5)

### Objectives
- Set up database migrations
- Create Dart entity models
- Establish repository interfaces

### Tasks

#### Task 1.1: Database Migration Setup
**Effort**: 4-6 hours
**Owner**: Backend Lead
**Status**: Ready (migration file created)

**Subtasks**:
- [ ] Apply migration: `20251101_add_exam_timetable_schema.sql`
  - Create `grade_sections` table
  - Create `teacher_subjects` table
  - Create `exam_calendar` table
  - Create `exam_timetables` table
  - Create `exam_timetable_entries` table
  - Modify `question_papers` (add section field)
  - Modify `notifications` (add new types)
  - Enable RLS policies

**Validation**:
```sql
-- Verify all tables created
SELECT tablename FROM pg_tables
WHERE tablename IN (
  'grade_sections', 'teacher_subjects', 'exam_calendar',
  'exam_timetables', 'exam_timetable_entries'
);

-- Verify column added to question_papers
SELECT column_name FROM information_schema.columns
WHERE table_name = 'question_papers' AND column_name = 'section';
```

#### Task 1.2: Dart Entity Models
**Effort**: 8-10 hours
**Owner**: Backend Developer
**Depends On**: Task 1.1

**Files to Create**:
```
lib/features/catalog/domain/entities/
  ├── grade_section.dart

lib/features/assignments/domain/entities/
  ├── teacher_subject.dart

lib/features/exams/domain/entities/
  ├── exam_calendar.dart
  ├── exam_timetable.dart
  └── exam_timetable_entry.dart
```

**Entity Classes Required**:
- `GradeSection` with JSON serialization
- `TeacherSubject` with JSON serialization
- `ExamCalendar` with JSON serialization
- `ExamTimetable` with JSON serialization and status enum
- `ExamTimetableEntry` with JSON serialization

**Tests Required**:
- Entity creation and equality tests
- JSON serialization/deserialization tests
- Enum value tests

**Acceptance Criteria**:
- [ ] All entities compile without errors
- [ ] JSON serialization works correctly
- [ ] All equality comparisons work
- [ ] Entity tests pass (100% coverage)

#### Task 1.3: Repository Interfaces
**Effort**: 6-8 hours
**Owner**: Backend Developer
**Depends On**: Task 1.2

**Files to Create**:
```
lib/features/catalog/domain/repositories/
  ├── grade_section_repository.dart

lib/features/assignments/domain/repositories/
  ├── teacher_subject_repository.dart

lib/features/exams/domain/repositories/
  ├── exam_calendar_repository.dart
  ├── exam_timetable_repository.dart
```

**Interfaces to Define**:
- `GradeSectionRepository` (CRUD + list operations)
- `TeacherSubjectRepository` (CRUD + bulk save + query by teacher/grade/subject)
- `ExamCalendarRepository` (CRUD + list by tenant)
- `ExamTimetableRepository` (CRUD + entries management)

**Acceptance Criteria**:
- [ ] All repository interfaces defined
- [ ] Method signatures match usage in usecases
- [ ] Dart analysis: no errors

---

### Phase 1 Milestone: Foundation Complete
**Success Criteria**:
- Database schema applied and verified
- All entity models created and tested
- All repository interfaces defined
- Zero compilation errors

**Go/No-Go Decision Point**: If any tests fail, resolve before proceeding to Phase 2.

---

## Phase 2: Backend Services & Business Logic (Week 2-4.5)

### Objectives
- Implement repository implementations
- Create use cases
- Build validation logic
- Implement paper auto-creation engine

### Tasks

#### Task 2.1: Repository Implementations
**Effort**: 12-16 hours
**Owner**: 1-2 Backend Developers
**Depends On**: Phase 1 Complete

**Files to Create**:
```
lib/features/catalog/data/repositories/
  ├── grade_section_repository_impl.dart

lib/features/assignments/data/repositories/
  ├── teacher_subject_repository_impl.dart

lib/features/exams/data/repositories/
  ├── exam_calendar_repository_impl.dart
  ├── exam_timetable_repository_impl.dart
```

**Implementations Required**:
- API calls using `ApiClient` (create, read, update, delete)
- Filtering by tenant_id (multi-tenancy)
- Error handling and conversion to Failures
- Batch operations for teacher_subjects

**Key Methods**:
```dart
// GradeSectionRepository
- getGradeSections(tenantId, gradeId?, activeOnly)
- createGradeSection(section)
- updateGradeSection(section)
- deleteGradeSection(id)

// TeacherSubjectRepository
- getTeacherSubjects(tenantId, teacherId?, academicYear)
- saveTeacherSubjects(tenantId, teacherId, academicYear, assignments)
- getTeachersFor(tenantId, gradeId, subjectId, section, academicYear)
- deactivateTeacherSubject(id)

// ExamTimetableRepository
- createTimetable(timetable)
- getTimetableById(id)
- getTimetablesForTenant(tenantId, academicYear?, status?)
- addTimetableEntry(entry)
- getTimetableEntries(timetableId)
- updateTimetableStatus(timetableId, status, publishedAt)
```

**Tests Required**:
- Mocked API responses
- Error handling tests
- Tenant isolation tests
- Batch operation tests

**Acceptance Criteria**:
- [ ] All repository methods implemented
- [ ] All unit tests pass
- [ ] Multi-tenancy verified
- [ ] Error handling complete

#### Task 2.2: Validation Services & Use Cases
**Effort**: 16-20 hours
**Owner**: 1-2 Backend Developers
**Depends On**: Task 2.1

**Files to Create**:
```
lib/features/assignments/domain/services/
  ├── teacher_subject_validator.dart

lib/features/assignments/domain/usecases/
  ├── save_teacher_subjects_usecase.dart
  ├── validate_teacher_subjects_usecase.dart

lib/features/exams/domain/usecases/
  ├── create_exam_calendar_usecase.dart
  ├── create_exam_timetable_usecase.dart
  ├── publish_exam_timetable_usecase.dart
  ├── add_timetable_entry_usecase.dart
  ├── validate_timetable_before_publish_usecase.dart
```

**Validation Logic Required**:
```dart
class TeacherSubjectValidator {
  // Validate grade-subject compatibility
  // Check subject_catalog.min_grade and max_grade

  // Validate no duplicate assignments

  // Validate section exists in grade_sections

  // Return ValidationError list
}
```

**Publish Timetable Validation**:
- Ensure all entries have at least one teacher assigned
- Check for scheduling conflicts (optional enhancement)
- Verify exam dates are in the future

**Use Cases**:
- `SaveTeacherSubjectsUseCase`: Validate + save assignments
- `CreateExamTimetableUseCase`: Create new timetable
- `PublishExamTimetableUseCase`: Validate + publish + create papers
- `AddTimetableEntryUseCase`: Validate + add entry

**Tests Required**:
- Validation tests (positive, negative, edge cases)
- Use case integration tests
- Mock repository tests

**Acceptance Criteria**:
- [ ] All validations working correctly
- [ ] Use cases implemented and tested
- [ ] Error messages user-friendly
- [ ] All unit tests pass (>90% coverage)

#### Task 2.3: Paper Auto-Creation Engine
**Effort**: 20-24 hours
**Owner**: 1-2 Senior Backend Developers
**Depends On**: Task 2.2

**Purpose**: When timetable is published, automatically create DRAFT papers for all assigned teachers.

**Implementation Strategy**:

**Synchronous Path** (for <500 entries):
```dart
Future<void> _createPapersSync(
  ExamTimetable timetable,
  List<ExamTimetableEntry> entries,
) async {
  for (final entry in entries) {
    // 1. Query teachers for (grade, subject, section)
    final teachers = await getTeachersFor(
      tenantId: timetable.tenantId,
      gradeId: entry.gradeId,
      subjectId: entry.subjectId,
      section: entry.section,
      academicYear: timetable.academicYear,
    );

    // 2. Create paper for each teacher
    for (final teacher in teachers) {
      await createPaper(QuestionPaper(
        tenantId: timetable.tenantId,
        userId: teacher.teacherId,
        subjectId: entry.subjectId,
        gradeId: entry.gradeId,
        section: entry.section,
        examDate: entry.examDate,
        examType: timetable.examType,
        examNumber: timetable.examNumber,
        title: '${subject.name} - ${timetable.examName}',
        status: 'draft',
        questions: [],
        paperSections: [],
      ));
    }
  }
}
```

**Asynchronous Path** (for >500 entries):
- Use background job queue (Firebase Cloud Tasks, or custom queue)
- Track progress in `job_status` table
- Send completion notification
- Implementation: Phase 4 (post-launch enhancement)

**Files to Create**:
```
lib/features/exams/domain/services/
  ├── paper_auto_creation_service.dart

lib/features/exams/data/datasources/
  ├── paper_creation_datasource.dart
```

**Tests Required**:
- Synchronous creation test (10, 50, 100, 500 entries)
- Verify correct number of papers created
- Verify paper data correctness
- Verify teacher assignment lookup
- Error recovery tests

**Performance Requirements**:
- 50 entries: <2 seconds
- 200 entries: <5 seconds
- 500 entries: <15 seconds
- 1000+ entries: Queue async job

**Acceptance Criteria**:
- [ ] Papers created correctly for all teachers
- [ ] Paper data matches timetable entry data
- [ ] Performance meets requirements
- [ ] All unit tests pass
- [ ] Error handling and logging complete

#### Task 2.4: Notification Service Integration
**Effort**: 8-10 hours
**Owner**: Backend Developer
**Depends On**: Task 2.3

**Purpose**: Send notifications after papers are created.

**Files to Create/Modify**:
```
lib/features/notifications/data/datasources/
  ├── notification_datasource.dart (extend existing)
```

**Notifications to Send**:
1. When paper is created: "New paper created: [Subject] Grade [Grade]-[Section]"
2. When timetable is published: "Timetable published, check your dashboard"
3. Paper submission deadline reminder (optional Phase 4)

**Implementation**:
```dart
Future<void> _sendPaperCreatedNotifications(
  ExamTimetable timetable,
  List<(String teacherId, QuestionPaper paper)> papers,
) async {
  for (final (teacherId, paper) in papers) {
    await notificationRepository.createNotification(
      userId: teacherId,
      tenantId: timetable.tenantId,
      type: NotificationType.paperCreated,
      title: 'New Paper Created',
      message: '${paper.subjectName} paper for Grade ${paper.gradeId}-${paper.section}',
      data: {'paperId': paper.id},
    );
  }
}
```

**Acceptance Criteria**:
- [ ] Notifications created in database
- [ ] Notification types correct
- [ ] User receives notifications in UI
- [ ] No duplicate notifications

---

### Phase 2 Milestone: Backend Complete
**Success Criteria**:
- All repositories implemented and tested
- All use cases implemented and tested
- Paper auto-creation engine working
- Notification system integrated
- Zero compilation errors
- >85% unit test coverage

**Integration Testing**:
```
Test Flow:
1. Create exam calendar
2. Create exam timetable
3. Add timetable entries
4. Publish timetable
5. Verify papers created
6. Verify notifications sent
7. Verify teacher can see papers
```

**Performance Baseline**:
- Create timetable: <500ms
- Add 50 entries: <5 seconds
- Publish timetable (50 entries): <10 seconds
- Query papers by teacher: <300ms

---

## Phase 3: Frontend Implementation (Week 4-6)

### Objectives
- Refactor teacher onboarding
- Build admin exam calendar UI
- Build admin timetable management UI
- Build grade sections management UI
- Enhance teacher dashboard

### Tasks

#### Task 3.1: Refactor TeacherProfileSetupPage
**Effort**: 12-16 hours
**Owner**: 1-2 Frontend Developers
**Depends On**: Phase 2 Complete (backend ready)

**Changes**:
1. Load grade sections from new API
2. Display interactive grid (grade × subject with sections)
3. Save to `teacher_subjects` table instead of separate grade + subject

**Implementation Steps**:
- [ ] Create `GradeSectionBloc`
- [ ] Refactor page to use data table/grid
- [ ] Add validation feedback
- [ ] Test with different section configurations

**UI Tests Required**:
- Render with 0, 1, 5+ sections per grade
- Select/deselect functionality
- Form validation
- Error handling

**Acceptance Criteria**:
- [ ] Page renders correctly
- [ ] Selections saved to database
- [ ] Validation works
- [ ] Responsive on mobile/tablet
- [ ] Accessible (labels, contrast, keyboard nav)

#### Task 3.2: Exam Calendar Management UI
**Effort**: 16-20 hours
**Owner**: 1-2 Frontend Developers
**Depends On**: Phase 2 Complete

**Screens**:
- `ExamCalendarListPage`: List all calendars
- `ExamCalendarCreatePage`: Create new exam
- `ExamCalendarDetailPage`: View exam details

**Implementation Steps**:
- [ ] Create `ExamCalendarBloc` with Load, Create events
- [ ] Build list screen with filters
- [ ] Build create form with validation
- [ ] Add delete confirmation dialog
- [ ] Add edit functionality (optional Phase 1)

**Form Validation**:
- Exam name required
- Month number 1-12
- Start date ≤ End date
- Deadline ≤ End date

**Tests Required**:
- Form validation tests
- BLoC state tests
- Navigation tests
- Data display tests

**Acceptance Criteria**:
- [ ] All CRUD operations work
- [ ] Form validation correct
- [ ] List displays properly
- [ ] Responsive design
- [ ] Accessible

#### Task 3.3: Exam Timetable Management UI
**Effort**: 24-32 hours
**Owner**: 2-3 Frontend Developers
**Depends On**: Task 3.2 Complete

**Screens**:
- `ExamTimetableListPage`: List timetables with filters
- `ExamTimetableCreatePage`: Create new timetable (from calendar or ad-hoc)
- `ExamTimetableEditPage`: Add/edit entries
- `AddTimetableEntryPage`: Add single entry
- `PublishConfirmationPage`: Publish with validation

**Complex Features**:
1. **Dual Path Creation**:
   - Option 1: Create from exam calendar
   - Option 2: Create ad-hoc (daily test)

2. **Entry Management**:
   - Show teachers assigned to each (grade, subject, section)
   - Display validation status
   - Prevent publish if missing teachers

3. **Publish Workflow**:
   - Validate all entries
   - Show summary
   - Confirm publishing
   - Show progress during paper creation
   - Show success message

**Implementation Steps**:
- [ ] Create `ExamTimetableBloc` with Create, Publish, GetEntries events
- [ ] Build list screen with status filters
- [ ] Build create flow (selection + ad-hoc)
- [ ] Build entry table/cards
- [ ] Build publish confirmation with validation
- [ ] Add loading/progress states

**Data Flow Validation**:
```
Create → Draft → Add Entries → Validate → Publish → Draft Papers Created
```

**Tests Required**:
- Form validation tests
- Multi-path flow tests
- BLoC state management tests
- Entry addition/removal tests
- Publish validation tests
- Error handling tests

**Acceptance Criteria**:
- [ ] Dual path creation works
- [ ] Entries displayed correctly
- [ ] Teachers show for each entry
- [ ] Publish validation prevents missing assignments
- [ ] Papers created after publish
- [ ] Responsive design
- [ ] Loading states show during publish
- [ ] Accessible

#### Task 3.4: Grade Sections Management UI
**Effort**: 10-12 hours
**Owner**: 1 Frontend Developer
**Depends On**: Phase 2 Complete

**Screen**: `ManageGradeSectionsPage`

**Features**:
- Display all grades with their sections
- Add new sections per grade
- Delete sections
- Save changes

**Implementation Steps**:
- [ ] Create `GradeSectionBloc` with Load, Create, Delete events
- [ ] Build page with grade cards
- [ ] Add section add/delete dialogs
- [ ] Implement save functionality

**Validation**:
- Section name required
- No duplicate sections per grade
- Cannot delete sections with assigned teachers (optional)

**Tests Required**:
- Add/delete functionality
- Validation tests
- BLoC state tests
- Error handling

**Acceptance Criteria**:
- [ ] All grades display
- [ ] Add section works
- [ ] Delete section works
- [ ] Validation correct
- [ ] Responsive

#### Task 3.5: Dashboard Enhancement
**Effort**: 8-10 hours
**Owner**: 1 Frontend Developer
**Depends On**: Phase 2 Complete

**Changes to Existing Components**:
1. Update `QuestionPaperCard`:
   - Show section (Grade 5-A, not just Grade 5)
   - Show deadline status badge (on-time ✓ or overdue ⚠)
   - Show exam type badge

2. Update `TeacherDashboard`:
   - Filter papers by section if needed
   - Show exam calendar (upcoming exams)

**Implementation Steps**:
- [ ] Modify `QuestionPaperCard` widget
- [ ] Add `ExamCalendarWidget` to dashboard
- [ ] Update paper query to include section
- [ ] Add deadline calculation logic

**Tests Required**:
- Widget tests
- Filter tests
- Deadline calculation tests

**Acceptance Criteria**:
- [ ] Papers show section
- [ ] Deadline badges show correctly
- [ ] Responsive
- [ ] No breaking changes to existing UI

---

### Phase 3 Milestone: Frontend Complete
**Success Criteria**:
- All 5 new screens implemented
- TeacherProfileSetupPage refactored
- Dashboard enhanced
- All widgets display correctly
- All BLoCs created and tested
- Responsive on mobile/tablet
- Accessible

**Manual Testing Checklist**:
- [ ] Create exam calendar end-to-end
- [ ] Create timetable from calendar
- [ ] Create ad-hoc timetable
- [ ] Add multiple entries
- [ ] Publish with validation
- [ ] Papers appear in teacher dashboard
- [ ] Teacher onboarding works
- [ ] All screens responsive

---

## Phase 4: Integration Testing & Polish (Week 5-6.5)

### Objectives
- Full end-to-end testing
- Performance optimization
- Error handling polish
- User acceptance testing

### Tasks

#### Task 4.1: End-to-End Testing
**Effort**: 16-20 hours
**Owner**: QA Engineer + 1 Developer
**Depends On**: Phase 3 Complete

**Test Scenarios**:

1. **Teacher Onboarding Flow**:
   - Login → Onboarding → Select (grade, section, subject) → Save → Dashboard

2. **Admin Calendar Setup Flow**:
   - Login → Settings → Create Exam Calendar → Add multiple exams → Verify saved

3. **Admin Timetable Creation Flow (From Calendar)**:
   - Create Timetable → Select from Calendar → Add entries → Check teacher assignment → Publish → Verify papers created

4. **Admin Timetable Creation Flow (Ad-hoc)**:
   - Create Timetable → Ad-hoc (daily test) → Add entries → Publish → Verify papers

5. **Paper Creation Verification**:
   - Publish timetable → Check papers in database → Verify in teacher dashboard → Count matches expected

6. **Teacher Dashboard Updates**:
   - Publish timetable → Refresh teacher dashboard → Verify new papers appear with section info → Verify deadline badges

7. **Error Handling**:
   - Try publish with unassigned entry → Should fail with clear message
   - Try save invalid section → Should fail with validation error
   - Try create duplicate assignment → Should fail

8. **Multi-Tenant Isolation**:
   - Create calendar in School A → Verify not visible in School B
   - Create timetable in School A → Verify not visible in School B

**Testing Tools**:
- Automated integration tests using `integration_test`
- Manual testing with test checklist
- Supabase direct SQL verification

**Acceptance Criteria**:
- [ ] All 8 scenarios pass
- [ ] No data leaks between tenants
- [ ] Error messages clear and actionable
- [ ] All paper counts correct
- [ ] All notification sent correctly

#### Task 4.2: Performance Optimization
**Effort**: 12-16 hours
**Owner**: 1 Senior Developer
**Depends On**: Phase 3 Complete + Initial E2E

**Performance Targets**:
- Paper creation (50 entries): <10 seconds
- Paper creation (500 entries): Use async job (queue for Phase 5)
- Timetable list load: <1 second
- Paper dashboard load: <1 second
- Validation (entries): <500ms

**Optimization Areas**:
1. **Database Queries**:
   - Add indexes (already done in migration)
   - Use batch queries where possible
   - Implement query result caching

2. **Frontend**:
   - Use `const` constructors
   - Implement `shouldRebuild` in BLoCs
   - Cache exam calendar (doesn't change often)
   - Lazy load timetable entries

3. **API Calls**:
   - Batch insert papers instead of N individual calls
   - Use `select()` with specific columns only

**Benchmarking**:
```dart
// Measure paper creation
final stopwatch = Stopwatch()..start();
await publishTimetable(timetableId);
stopwatch.stop();
print('Papers created in ${stopwatch.elapsedMilliseconds}ms');
```

**Acceptance Criteria**:
- [ ] All performance targets met
- [ ] No noticeable UI lag
- [ ] Batch operations working
- [ ] Caching implemented where appropriate

#### Task 4.3: Error Handling & Logging
**Effort**: 8-10 hours
**Owner**: 1 Developer
**Depends On**: Phases 2-3

**Implementation**:
- [ ] Comprehensive error logging in all use cases
- [ ] User-friendly error messages
- [ ] Sentry integration for error tracking (if available)
- [ ] Detailed audit logging for admin actions

**Error Scenarios to Handle**:
1. Network errors during paper creation
2. Database constraint violations
3. Missing section definitions
4. Missing teacher assignments
5. Validation failures at multiple levels
6. Concurrent edits to same timetable

**Logging Strategy**:
```dart
// Log important events
AppLogger.info(
  'Timetable published',
  category: LogCategory.exams,
  context: {
    'timetableId': id,
    'entryCount': entries.length,
    'paperCount': papersCreated,
    'publishedAt': DateTime.now().toIso8601String(),
  },
);

// Log errors with context
AppLogger.error(
  'Paper creation failed',
  error: exception,
  category: LogCategory.exams,
  context: {
    'timetableId': id,
    'attemptedPaperCount': attempted,
    'successfulPaperCount': successful,
  },
);
```

**Acceptance Criteria**:
- [ ] All errors logged with context
- [ ] User sees helpful error messages
- [ ] Admin can see error logs
- [ ] No unhandled exceptions

#### Task 4.4: User Acceptance Testing
**Effort**: 8-12 hours (done by school admins/teachers)
**Owner**: Product Manager
**Depends On**: Phase 3 Complete

**UAT Scenarios**:
1. Admin creates exam calendar (realistic data from school)
2. Admin creates multiple timetables (daily tests + monthly tests)
3. Teachers onboard and select their sections
4. Teachers see papers in dashboard
5. Teachers create papers
6. Admin views reports/analytics (future feature)

**Feedback Collection**:
- UI/UX feedback
- Performance feedback
- Feature completeness
- Data correctness

**Sign-Off**: School admin confirms system works as expected

---

### Phase 4 Milestone: Integration Complete
**Success Criteria**:
- All E2E tests pass
- Performance targets met
- All errors handled gracefully
- UAT sign-off received
- Zero critical bugs
- User documentation complete

---

## Phase 5: Deployment & Launch (Week 6.5-7)

### Pre-Launch Checklist

#### Database
- [ ] Backup database before migration
- [ ] Test migration on staging database
- [ ] Verify all tables created successfully
- [ ] Verify indexes created
- [ ] Test RLS policies
- [ ] Run data integrity checks

#### Backend
- [ ] All use cases tested in production environment
- [ ] API endpoints responding correctly
- [ ] Database queries optimized
- [ ] Error logging configured
- [ ] Performance monitoring set up

#### Frontend
- [ ] All screens tested in production build
- [ ] Responsive design tested on devices
- [ ] Offline mode handled gracefully
- [ ] Loading states display correctly
- [ ] Error messages clear

#### Data & Security
- [ ] Tenant isolation verified
- [ ] No data leaks in logs
- [ ] RLS policies enforced
- [ ] Audit logging working
- [ ] Credentials not in code

#### Documentation
- [ ] API documentation complete
- [ ] Database schema documented
- [ ] Deployment guide written
- [ ] Rollback procedure documented
- [ ] Admin user guide written

### Deployment Steps

#### Step 1: Database Migration (off-peak, ~30 minutes)
```bash
# 1. Create backup
pg_dump -U postgres -d papercraft > backup_$(date +%s).sql

# 2. Apply migration
psql -U postgres -d papercraft < supabase/migrations/20251101_add_exam_timetable_schema.sql

# 3. Verify
SELECT count(*) FROM grade_sections;
SELECT count(*) FROM teacher_subjects;
SELECT count(*) FROM exam_calendar;
SELECT count(*) FROM exam_timetables;
SELECT count(*) FROM exam_timetable_entries;

# 4. Test RLS policies
SELECT count(*) FROM grade_sections WHERE tenant_id = '<test-tenant-id>';
```

#### Step 2: Backend Deployment
```bash
# 1. Build backend
flutter pub get
dart analyze

# 2. Deploy to backend (specific to your infrastructure)
# Example: Update Cloud Functions, App Engine, etc.

# 3. Verify APIs responding
curl https://api.papercraft.com/health

# 4. Monitor logs
tail -f logs/production.log
```

#### Step 3: Frontend Deployment
```bash
# 1. Build release APK/IPA
flutter build apk --release
flutter build ios --release

# 2. Deploy to app stores (if applicable)
# Or distribute via internal store

# 3. Verify in production
# Test with real user account
```

#### Step 4: Feature Flag Rollout (Optional)
If using feature flags, enable gradually:
- [ ] 10% of users (Day 1)
- [ ] 50% of users (Day 2)
- [ ] 100% of users (Day 3)

Monitor errors at each level before proceeding.

#### Step 5: Monitoring & Alerts
Set up alerts for:
- [ ] Database connection errors
- [ ] Paper creation failures
- [ ] RLS policy violations
- [ ] High API latency
- [ ] User complaints

### Rollback Procedure

**If Critical Issue Found** (within 24 hours):

```bash
# 1. Rollback frontend
# Deploy previous version from app store/internal distribution

# 2. Rollback database (only if absolutely necessary)
# Restore from backup and re-apply only essential fixes

# 3. Notify users
# Send message explaining issue and timeline for fix

# 4. Investigate root cause
# Document issue and prevention measures
```

**Issues Requiring Rollback**:
- Data corruption (papers with wrong teacher)
- RLS policy bypasses (data leakage)
- Cascading deletion failures (data loss)
- Critical performance degradation

**Issues NOT Requiring Rollback** (Fix in hotfix):
- UI glitches
- Minor validation issues
- Notification delays
- Specific error messages

---

## Phase 5 Milestone: System Live
**Success Criteria**:
- [ ] Database migrated successfully
- [ ] All APIs responding
- [ ] No error spikes in logs
- [ ] Users can create timetables
- [ ] Papers auto-create correctly
- [ ] Teachers see papers in dashboard
- [ ] No data leaks reported
- [ ] Performance within targets

---

## Post-Launch (Week 8+)

### Monitoring & Support (Week 1-2)
- Daily log review
- User issue triage
- Hotfix deployment if needed
- Performance baseline establishment

### Planned Enhancements (Week 3+)
1. **Async Paper Creation** (for 500+ entry timetables)
   - Implement background job queue
   - Add progress tracking
   - User notifications of completion

2. **Paper Submission Deadline Reminders**
   - Auto-send reminder notifications
   - Configurable days before deadline

3. **Exam Conflict Detection**
   - Alert admin if exam times overlap
   - Suggest alternative times

4. **Paper Analytics**
   - Track paper creation patterns
   - Difficulty distribution
   - Teacher workload insights

5. **Report Generation**
   - Admin can export timetables to PDF
   - Teacher assignment reports
   - Exam calendar reports

---

## Resource Allocation

### Team Composition

**Frontend Team** (2-3 developers):
- Lead: 1 senior frontend developer
- Team: 1-2 junior/mid-level frontend developers
- Effort: ~200-240 hours

**Backend Team** (2-3 developers):
- Lead: 1 senior backend developer
- Team: 1-2 junior/mid-level backend developers
- Effort: ~280-320 hours

**QA** (1 person, part-time):
- Effort: ~80 hours (testing throughout phases)

**Product/PM** (1 person):
- Effort: ~60 hours (planning, UAT, docs)

**Total Effort**: ~700-840 person-hours = 6-8 weeks full-time, 3-4 months part-time

### Weekly Standup Agenda
- [ ] Progress on assigned tasks
- [ ] Blockers and dependencies
- [ ] Quality metrics (test coverage, bugs)
- [ ] Timeline adjustments if needed

---

## Risk Management

### Identified Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Paper creation too slow | Medium | High | Benchmark early, use async for >500 entries |
| Teacher onboarding complexity | Medium | Medium | Simple UI, clear instructions, help doc |
| RLS policy issues | Low | Critical | Test RLS thoroughly in Phase 2 |
| Data migration issues | Low | Critical | Test on staging, backup before prod |
| Namespace collisions (section names) | Low | Medium | Validation, error messages |
| Section definition missing | Medium | Medium | Admin checklist, validation before publish |
| Concurrent timetable edits | Low | Medium | Database constraints, optimistic locking |

### Contingency Plans

**If Paper Creation Too Slow**:
- Implement async queue (Phase 5 enhancement, not blocker)
- Show progress to admin
- Create papers in batches

**If Onboarding Complex**:
- Add video tutorial
- Add tooltips/help text
- Simplify UI further

**If RLS Issues**:
- Fall back to app-level filtering (less secure but functional)
- Investigate and fix asap
- May require hotfix deployment

---

## Success Metrics

### Functional Metrics
- ✅ Teachers can onboard and select their classes (100% success rate)
- ✅ Admin can create exam calendar (100% success rate)
- ✅ Admin can create timetables (100% success rate)
- ✅ Papers auto-create after publish (100% of papers created within 15 seconds)
- ✅ Teachers see papers in dashboard within 1 minute of publishing

### Performance Metrics
- ✅ Timetable publish: <15 seconds for 500 entries
- ✅ Paper dashboard load: <1 second
- ✅ API response time: <500ms (95th percentile)
- ✅ Database query time: <200ms for common queries

### Reliability Metrics
- ✅ System uptime: >99.5%
- ✅ Zero data loss incidents
- ✅ Zero tenant data leakage
- ✅ Error rate: <0.1%

### User Adoption Metrics
- ✅ >80% of teachers complete onboarding in first week
- ✅ >90% of timetables created use new system within 1 month
- ✅ User satisfaction score: >4/5

---

## Sign-Off & Go-Live

### Stakeholder Approvals Required
- [ ] Product Manager: Feature complete
- [ ] Engineering Lead: Code quality acceptable
- [ ] QA Lead: All tests pass
- [ ] Operations: Deployment procedure ready
- [ ] School Admin (UAT): System meets requirements

### Go-Live Decision
```
All Phase Milestones Complete?
  ├─ YES → Deploy to production
  └─ NO → Fix blockers, re-test
```

---

## Document Versions & Changes

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-01 | Initial roadmap created |

---

## Appendix: Daily Task Examples

### Week 1 Sample Daily Tasks
- **Day 1**: Database migration setup, entity model skeleton
- **Day 2-3**: Complete all entity models with tests
- **Day 4-5**: Repository interfaces and basic implementations
- **Day 6**: Integration tests between entities and repos

### Week 2 Sample Daily Tasks
- **Day 1-2**: Complete repository implementations
- **Day 3-4**: Validation services and use cases
- **Day 5-6**: Paper auto-creation engine
- **Day 7**: Integration testing and refactoring

### Week 3 Sample Daily Tasks
- **Day 1-2**: Notification integration and testing
- **Day 3-4**: BLoC implementation and testing
- **Day 5-6**: Frontend screen development begins
- **Day 7**: Code review and bug fixes

---

## Questions & Clarifications

**Q: Can we start frontend before backend is complete?**
A: Yes, partially. Create mock repositories and test UI in parallel after Phase 1 foundation is complete. This can save 1-2 weeks.

**Q: What if we need to modify section definitions after publishing timetable?**
A: New sections can be added, but old sections should remain. Papers use section value directly, so old papers stay valid. New papers use new sections only.

**Q: How do we handle teachers who teach the same subject across multiple sections?**
A: They get one assignment per section. Example: Grade 5-A Math + Grade 5-B Math = 2 rows in teacher_subjects. When timetable published, they get 2 papers (one per section).

**Q: What about year rollover (moving to new academic year)?**
A: Teachers re-onboard or assignments auto-copy from previous year (Phase 4+ enhancement). For now, they select again each year.

**Q: Can admin edit timetable after publishing?**
A: No, to maintain data integrity. If changes needed, cancel and create new timetable (Phase 4+ enhancement: allow edit with paper re-creation).
