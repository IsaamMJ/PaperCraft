# Exam Timetable Phase 1 - Complete Implementation Guide

## 🎯 Quick Summary

**Phase 1 Objective**: Build a complete exam timetable management system where admins can create exam calendars and timetables with individual exam entries.

**Status**: Task 1 & 2 (Database) COMPLETE ✅

**All Documentation**: 4 files covering everything from schema design to testing checklist.

---

## 📚 Documentation Files

| File | Purpose | Location |
|------|---------|----------|
| `TIMETABLE_PHASE1_README.md` | This file - quick reference | Project root |
| `TIMETABLE_PHASE1_DATABASE_SUMMARY.md` | Database schema overview & quick start | Project root |
| `TIMETABLE_PHASE1_IMPLEMENTATION_CHECKLIST.md` | Task-by-task checklist with specifications | Project root |
| `supabase/migrations/20251107_create_exam_tables.sql` | Main database migration (350 lines) | supabase/migrations/ |
| `supabase/migrations/20251107_exam_tables_rls_policies.sql` | RLS policies (280 lines) | supabase/migrations/ |
| `supabase/migrations/EXAM_TIMETABLE_MIGRATION_GUIDE.md` | Detailed migration guide (400 lines) | supabase/migrations/ |

---

## 🚀 Getting Started

### Step 1: Apply Database Migrations (5 minutes)
```bash
1. Open Supabase dashboard
2. Go to SQL Editor → New Query
3. Copy entire content of: supabase/migrations/20251107_create_exam_tables.sql
4. Click Run ▶️
5. Repeat steps 2-4 with: supabase/migrations/20251107_exam_tables_rls_policies.sql
6. Done! Database is ready
```

### Step 2: Verify Migrations (2 minutes)
See verification queries in:
- `TIMETABLE_PHASE1_DATABASE_SUMMARY.md` → "Verification Checklist" section
- `supabase/migrations/EXAM_TIMETABLE_MIGRATION_GUIDE.md` → "Migration Steps"

### Step 3: Start Coding (Next: Domain Entities)
Follow: `TIMETABLE_PHASE1_IMPLEMENTATION_CHECKLIST.md` → Task 3

---

## 🗄️ Database Schema

### Three-Table Hierarchy

```
EXAM_CALENDAR (Template/Master)
    ↓
EXAM_TIMETABLES (Specific Year Instance)
    ↓
EXAM_TIMETABLE_ENTRIES (Individual Exams)
    ↓
QUESTION_PAPERS (Enhanced with exam tracking)
```

### Quick Field Reference

| Table | Key Fields | Purpose |
|-------|-----------|---------|
| exam_calendar | exam_name, exam_type, date_range | Reusable exam period template |
| exam_timetables | academic_year, status, created_by | Specific year's timetable instance |
| exam_timetable_entries | grade_id, subject_id, date, time | Individual exam: Grade 10 Maths on Nov 15 @9AM |
| question_papers | exam_timetable_entry_id, submission_status | Paper linked to exam, tracks workflow |

---

## 🔑 Key Features Implemented

✅ **Duplicate Prevention**: UNIQUE constraint on (grade, subject, date)
✅ **Data Isolation**: RLS policies enforce tenant separation
✅ **Admin Control**: Only admins can modify timetables
✅ **Soft Deletes**: is_active flag for safe deletion
✅ **Audit Trail**: created_by, created_at track ownership
✅ **Performance**: 13 strategic indexes
✅ **Validation**: Time range, date constraints, enum checks
✅ **Workflow Status**: draft → published → archived

---

## 📋 Complete Task Breakdown

### ✅ Task 1: Database Migrations - COMPLETE
**What**: Created 3 tables + 15 RLS policies + 13 indexes
**Files**: 2 SQL migrations + 3 documentation files
**Time**: ~1-2 hours to apply

### ✅ Task 2: RLS Policies - COMPLETE
**What**: Security policies for data isolation
**Included in**: `20251107_exam_tables_rls_policies.sql`
**Time**: Applied with migrations

### ⏳ Task 3: Domain Entities - NEXT
**What**: Create 3 Dart entity classes
**Where**: `lib/features/timetable/domain/entities/`
**Files**: 3 files (exam_calendar_entity.dart, exam_timetable_entity.dart, exam_timetable_entry_entity.dart)
**Specs**: See checklist Task 3 section
**Est. Time**: 1-2 hours

### ⏳ Task 4: Data Layer (Repositories)
**What**: CRUD operations with error handling
**Where**: `lib/features/timetable/data/`
**Pattern**: Either<Failure, T> using dartz
**Est. Time**: 3-4 hours

### ⏳ Task 5: Use Cases
**What**: 9 use cases for business logic
**Where**: `lib/features/timetable/domain/usecases/`
**Examples**: CreateExamCalendarUseCase, ValidateExamTimetableUseCase
**Est. Time**: 2-3 hours

### ⏳ Task 6: BLoC State Management
**What**: ExamTimetableBloc with 10+ events
**Where**: `lib/features/timetable/presentation/bloc/`
**Features**: Multi-step form support, duplicate validation, caching
**Est. Time**: 2-3 hours

### ⏳ Task 7: UI Pages (3 pages)
**What**: 3 admin pages for timetable management
**7.1 Calendar Page**: Create/edit exam calendars
**7.2 Wizard Page**: 3-step timetable creation
**7.3 Management Page**: List and manage timetables
**Est. Time**: 6-8 hours

### ⏳ Task 8: Validation & Error Handling
**What**: Input validation + user-friendly errors
**Where**: BLoC + Pages
**Est. Time**: 2-3 hours

### ⏳ Task 9: Unit Tests
**What**: 80%+ code coverage
**Where**: test/features/timetable/
**Est. Time**: 2-3 hours

### ⏳ Task 10: End-to-End Testing
**What**: Manual testing of complete flow
**Scenarios**: Create, edit, publish, verify persistence
**Est. Time**: 1-2 hours

---

## 📊 Implementation Progress

```
Task 1:  ████████████████████ 100% ✅
Task 2:  ████████████████████ 100% ✅
Task 3:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 4:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 5:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 6:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 7:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 8:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 9:  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Task 10: ░░░░░░░░░░░░░░░░░░░░   0% ⏳

Total Progress: 17% (2/12 tasks complete)
Estimated Remaining: 14-22 hours
```

---

## 🎯 What You'll Be Able to Do

### By End of Phase 1

✅ **Admin creates exam calendar** (template)
- Exam name: "Mid-term Exams"
- Exam type: "mid_term"
- Planned dates: Nov 10-30
- Paper deadline: Nov 5

✅ **Admin creates timetable** (specific year)
- Based on calendar
- Academic year: 2025-2026
- Status: draft

✅ **Admin adds exam entries** (individual exams)
- Grade 10, English, Nov 15, 9:00-11:00 AM
- Grade 10, Mathematics, Nov 16, 10:00 AM-12:00 PM
- Grade 11, Physics, Nov 17, 2:00-4:00 PM
- (and more...)

✅ **System prevents duplicates**
- Cannot add same grade+subject on same date

✅ **Admin publishes timetable**
- Status changes: draft → published
- Entries are now locked (Phase 2: teachers can see them)

✅ **Admin manages timetables**
- View all timetables
- Filter by year/status
- Edit draft timetables
- Duplicate templates for quick setup
- Delete drafts

---

## 🔧 Architecture Overview

### Layered Architecture
```
┌─────────────────────────────────┐
│    PRESENTATION (UI Layer)      │
│  Pages, Widgets, BLoC, Events   │
├─────────────────────────────────┤
│    DOMAIN (Business Logic)      │
│  Entities, Repositories, UseCases│
├─────────────────────────────────┤
│    DATA (Backend Integration)   │
│  DataSources, Models, Repos     │
├─────────────────────────────────┤
│    DATABASE (Supabase)          │
│  Tables, RLS, Triggers, Indexes │
└─────────────────────────────────┘
```

### Tech Stack
- **Frontend**: Flutter + BLoC + GetIt
- **State Mgmt**: flutter_bloc + dartz (Either pattern)
- **Database**: Supabase (PostgreSQL)
- **Validation**: Custom validators + constraints
- **Testing**: Mockito + flutter_test

---

## 📝 Important Constraints

| Constraint | Purpose | Level |
|-----------|---------|-------|
| `UNIQUE(timetable_id, grade_id, subject_id, section, date)` | **Prevent duplicates** | DB |
| `start_time < end_time` | Valid exam times | DB |
| `planned_start_date <= planned_end_date` | Valid date range | DB |
| `duration_minutes = EXTRACT(EPOCH FROM (end_time - start_time))/60` | Time consistency | DB |
| Only admins can insert/update/delete | Access control | RLS |
| Users only see own tenant data | Data isolation | RLS |
| Status enum: draft/published/archived | Valid states | Check |

---

## 🧪 Testing Strategy

### Unit Tests (Task 9)
- Test each use case independently
- Test BLoC state transitions
- Test validation logic
- Mock repository calls

### E2E Tests (Task 10)
- Create calendar → Timetable → Entries → Publish
- Verify duplicate prevention
- Verify data persistence
- Verify RLS isolation

### Manual Testing
- Create 10+ exam entries
- Publish timetable
- Log out/in and verify data persists
- Try operations as non-admin (should fail)

---

## 🔐 Security Features

✅ **RLS Policies**: 15 policies for data isolation
✅ **Admin Authorization**: Only admins modify timetables
✅ **Tenant Isolation**: Users only see their school's data
✅ **Audit Trail**: who, what, when tracked
✅ **Input Validation**: Constraints prevent invalid data
✅ **Soft Deletes**: Never lose data, always recoverable

---

## 📱 UI Structure

### Admin Dashboard → Timetable Management

```
Settings Screen (existing)
    ↓
Management Tab (existing)
    ├── Grades & Sections (existing)
    ├── Subjects (existing)
    └── Exams & Timetables (NEW - Phase 1)
        ├── Calendar Management
        │   └── Create/Edit/Delete Calendars
        ├── Timetable Wizard
        │   ├── Step 1: Basic Info
        │   ├── Step 2: Add Entries
        │   └── Step 3: Review & Publish
        └── Timetable Management
            └── List/Filter/Edit/Duplicate/Delete
```

---

## 💾 Data Migration Path

### If Migrating from Old System
1. Create exam calendars for historical exams
2. Create timetables for each academic year
3. Link existing question papers to exam entries (Phase 2)
4. Verify all data migrated correctly

---

## 🐛 Troubleshooting

### Issue: RLS policy not working
**Solution**: Check that profile.role = 'admin' and user is authenticated

### Issue: Duplicate entry constraint violation
**Solution**: Check for existing entry with same grade+subject+date (may be inactive)

### Issue: Time constraint violation
**Solution**: Ensure start_time < end_time and duration matches

### Issue: Entries disappear after reload
**Solution**: Check that is_active = true (not soft deleted)

---

## 📞 Quick Reference

### File Structure
```
lib/features/timetable/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── bloc/
    ├── pages/
    └── widgets/

supabase/migrations/
├── 20251107_create_exam_tables.sql
├── 20251107_exam_tables_rls_policies.sql
└── EXAM_TIMETABLE_MIGRATION_GUIDE.md
```

### Key Queries
```sql
-- Get all timetables for tenant
SELECT * FROM exam_timetables
WHERE tenant_id = '<id>' AND academic_year = '2025-2026';

-- Get entries for timetable
SELECT * FROM exam_timetable_entries
WHERE exam_timetable_id = '<id>' ORDER BY exam_date;

-- Check for duplicates
SELECT COUNT(*) FROM exam_timetable_entries
WHERE exam_timetable_id = '<id>'
AND grade_id = '<grade>'
AND subject_id = '<subject>'
AND exam_date = '<date>';
```

---

## 🎓 Learning Resources

- **BLoC Pattern**: https://bloclibrary.dev
- **Supabase RLS**: https://supabase.com/docs/guides/database/postgres/row-level-security
- **Clean Architecture**: See existing code in project (auth, assignments)
- **Either Pattern**: dartz package documentation

---

## ✨ Next Phase Preview

### Phase 2: Teacher Integration
- Auto-assign teachers to exam entries
- Teacher dashboard showing "papers to create"
- Notification system for deadlines
- Paper submission tracking
- Admin review & approval workflow

### Phase 3: Analytics
- Reports on paper submission rates
- Teacher performance insights
- Exam calendar analysis
- Historical data tracking

---

## 📊 Project Statistics

| Metric | Value |
|--------|-------|
| SQL Lines | 630 |
| Tables Created | 3 |
| RLS Policies | 15 |
| Indexes | 13 |
| Documentation Pages | 4 |
| Tasks in Phase 1 | 12 |
| Estimated Hours | 16-24 |
| Code Lines (Est. final) | 3000+ |
| Tests (Est.) | 50+ |

---

## 🏁 Final Checklist Before Starting Coding

- [ ] Read `TIMETABLE_PHASE1_DATABASE_SUMMARY.md`
- [ ] Apply migrations to Supabase
- [ ] Run verification queries
- [ ] Confirm all tables exist with RLS enabled
- [ ] Read Task 3 in `TIMETABLE_PHASE1_IMPLEMENTATION_CHECKLIST.md`
- [ ] Create domain entities directory structure
- [ ] Start with ExamCalendarEntity

---

## 📞 Support

- **Schema Questions**: See `TIMETABLE_PHASE1_DATABASE_SUMMARY.md`
- **Migration Issues**: See `supabase/migrations/EXAM_TIMETABLE_MIGRATION_GUIDE.md`
- **Task Specifications**: See `TIMETABLE_PHASE1_IMPLEMENTATION_CHECKLIST.md`
- **Architecture**: Follow existing pattern in auth/assignments features

---

**Phase 1 Status**: 17% Complete (2/12 Tasks Done)
**Next Task**: Task 3 - Domain Entities
**Last Updated**: 2025-11-07
**Ready to Code**: ✅ YES

Good luck! 🚀
