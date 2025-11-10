# Exam Timetable System - Database Migration Guide

## Overview

This migration sets up the complete database infrastructure for the exam timetable management system. It creates three new core tables and enhances the existing `question_papers` table with exam tracking functionality.

---

## Migration Files

### 1. `20251107_create_exam_tables.sql`
Creates the core tables for the exam timetable system.

**Tables Created:**
- `exam_calendar` - Master template for exam periods
- `exam_timetables` - Actual timetable instances
- `exam_timetable_entries` - Individual exam entries (grade+subject+date)
- Alters `question_papers` to add exam tracking columns

### 2. `20251107_exam_tables_rls_policies.sql`
Sets up Row Level Security policies for data isolation and access control.

**Policies:**
- Tenants can only see their own exam data
- Only admins can create/edit/delete timetables and entries
- Teachers can see entries they're assigned to

---

## Table Structures

### `exam_calendar`
Master template for exam periods - reusable across years.

```
id                      UUID (PK)
tenant_id              UUID (FK → tenants)
exam_name              TEXT         (e.g., "Mid-term Exams")
exam_type              TEXT         (e.g., "mid_term", "final")
month_number           INTEGER      (1-12)
planned_start_date     DATE
planned_end_date       DATE
paper_submission_deadline DATE
display_order          INTEGER
metadata               JSONB
is_active              BOOLEAN
created_at             TIMESTAMP
updated_at             TIMESTAMP
```

### `exam_timetables`
Actual exam timetable for a specific academic year.

```
id                      UUID (PK)
tenant_id              UUID (FK → tenants)
created_by             UUID (FK → profiles) [Admin who created it]
exam_calendar_id       UUID (FK → exam_calendar) [Optional reference]
exam_name              TEXT
exam_type              TEXT
exam_number            INTEGER      (1st, 2nd attempt, etc.)
academic_year          TEXT         (e.g., "2025-2026")
status                 TEXT         (draft, published, archived)
published_at           TIMESTAMP
paper_submission_deadline TIMESTAMP
is_active              BOOLEAN
metadata               JSONB
created_at             TIMESTAMP
updated_at             TIMESTAMP
```

### `exam_timetable_entries`
Individual exam entry: one per subject per grade per exam.

```
id                      UUID (PK)
tenant_id              UUID (FK → tenants)
exam_timetable_id      UUID (FK → exam_timetables) [Which timetable]
grade_id               UUID (FK → grades)
subject_id             UUID (FK → subjects)
grade_section_id       UUID (FK → grade_sections)
section                TEXT         (A, B, C) [Redundant with FK for convenience]
exam_date              DATE
start_time             TIME
end_time               TIME
duration_minutes       INTEGER      [Auto-validated from start/end times]
assigned_teacher_id    UUID (FK → profiles) [Teacher assigned to create paper]
assignment_status      TEXT         (pending, acknowledged, in_progress)
is_active              BOOLEAN
created_at             TIMESTAMP
updated_at             TIMESTAMP
```

### `question_papers` (Enhanced)
New columns added to track exam relationship.

```
exam_timetable_entry_id    UUID (FK → exam_timetable_entries) [Which exam entry this paper belongs to]
submission_status          TEXT (draft, submitted, under_review, approved, rejected)
```

---

## Key Constraints & Validations

### `exam_calendar`
- `planned_start_date <= planned_end_date`
- UNIQUE constraint on `(tenant_id, exam_name, exam_type, planned_start_date)`

### `exam_timetables`
- `status` must be one of: 'draft', 'published', 'archived'

### `exam_timetable_entries`
- `start_time < end_time`
- `EXTRACT(EPOCH FROM (end_time - start_time))/60 = duration_minutes` (ensures time consistency)
- UNIQUE constraint on `(exam_timetable_id, grade_id, subject_id, section, exam_date)` - **Prevents duplicate exams on same date**
- `assignment_status` must be one of: 'pending', 'acknowledged', 'in_progress'

### `question_papers`
- `submission_status` must be one of: 'draft', 'submitted', 'under_review', 'approved', 'rejected'

---

## Indexes Created

For optimal query performance:

**exam_calendar**
- `idx_exam_calendar_tenant` - Fast filtering by tenant
- `idx_exam_calendar_active` - Quick access to active calendars
- `idx_exam_calendar_type` - Query by exam type

**exam_timetables**
- `idx_exam_timetables_tenant` - Tenant isolation
- `idx_exam_timetables_academic_year` - Filter by academic year
- `idx_exam_timetables_status` - Query by status (draft/published)
- `idx_exam_timetables_calendar` - Reference lookups
- `idx_exam_timetables_created_by` - Track by creator

**exam_timetable_entries**
- `idx_exam_timetable_entries_timetable` - Join with timetables
- `idx_exam_timetable_entries_grade_subject` - Fast grade+subject lookups
- `idx_exam_timetable_entries_date` - Query by exam date
- `idx_exam_timetable_entries_teacher` - Find entries assigned to teacher
- `idx_exam_timetable_entries_active` - Active entries only

**question_papers** (new)
- `idx_question_papers_timetable_entry` - Find papers for exam entry
- `idx_question_papers_submission_status` - Track submission workflow

---

## RLS (Row Level Security) Policies

### Design Principles
- **Tenant Isolation**: Each tenant sees only their own data
- **Admin-Only Writes**: Only admins can create/modify timetables
- **Role-Based Access**: Teachers can see entries assigned to them

### Policies by Table

#### exam_calendar
- **SELECT**: Users can see calendars of their tenant
- **INSERT**: Only admins
- **UPDATE**: Only admins
- **DELETE**: Only admins

#### exam_timetables
- **SELECT**: Users can see timetables of their tenant
- **INSERT**: Only admins (and must set created_by to current user)
- **UPDATE**: Only admins
- **DELETE**: Only admins

#### exam_timetable_entries
- **SELECT**: Users can see entries from their tenant's timetables
- **INSERT**: Only admins (and entry must belong to tenant's timetable)
- **UPDATE**: Only admins
- **DELETE**: Only admins

#### question_papers (enhanced)
- **SELECT**: Teachers can see papers assigned to their timetable entries (in Phase 2)

---

## Migration Steps

### Step 1: Backup Your Database
```bash
# Use Supabase dashboard to create a backup
# Settings → Backups → Create Backup
```

### Step 2: Apply Migrations via Supabase Dashboard

#### Option A: Using SQL Editor (Recommended)
1. Go to Supabase Dashboard → Your Project
2. Click "SQL Editor" in left sidebar
3. Click "New Query"
4. Copy the entire content of `20251107_create_exam_tables.sql`
5. Paste into the editor
6. Click "Run" (green play button)
7. Wait for success message
8. Repeat for `20251107_exam_tables_rls_policies.sql`

#### Option B: Using Migration CLI
```bash
# If you have Supabase CLI installed
supabase migration new create_exam_tables
# Then copy the SQL content into the created migration file
supabase db push
```

### Step 3: Verify Migration Success

Run these queries to verify tables were created:

```sql
-- Check exam_calendar exists
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'exam_calendar';

-- Check exam_timetables exists
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'exam_timetables';

-- Check exam_timetable_entries exists
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'exam_timetable_entries';

-- Check question_papers has new columns
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'question_papers'
AND column_name IN ('exam_timetable_entry_id', 'submission_status');

-- Check RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE tablename IN ('exam_calendar', 'exam_timetables', 'exam_timetable_entries');
```

### Step 4: Test RLS Policies

```sql
-- These should work (admin with correct tenant)
SELECT * FROM exam_calendar WHERE tenant_id = '<your-tenant-id>';

-- Check policies exist
SELECT schemaname, tablename, policyname FROM pg_policies
WHERE tablename IN ('exam_calendar', 'exam_timetables', 'exam_timetable_entries');
```

---

## Rollback Steps (If Needed)

### Complete Rollback
```sql
-- Drop tables (removes all exam data - BE CAREFUL!)
DROP TABLE IF EXISTS exam_timetable_entries CASCADE;
DROP TABLE IF EXISTS exam_timetables CASCADE;
DROP TABLE IF EXISTS exam_calendar CASCADE;

-- Remove columns from question_papers
ALTER TABLE question_papers DROP COLUMN IF EXISTS exam_timetable_entry_id;
ALTER TABLE question_papers DROP COLUMN IF EXISTS submission_status;

-- Drop indexes
DROP INDEX IF EXISTS idx_question_papers_timetable_entry;
DROP INDEX IF EXISTS idx_question_papers_submission_status;
```

---

## Sample Test Data (Optional)

```sql
-- Create sample exam calendar
INSERT INTO exam_calendar (tenant_id, exam_name, exam_type, month_number, planned_start_date, planned_end_date, display_order)
VALUES (
  '<your-tenant-id>',
  'Mid-term Exams',
  'mid_term',
  11,
  '2025-11-10'::date,
  '2025-11-30'::date,
  1
);

-- Create sample timetable
INSERT INTO exam_timetables (tenant_id, created_by, exam_name, exam_type, academic_year, status)
VALUES (
  '<your-tenant-id>',
  '<admin-user-id>',
  'Mid-term Exams 2025',
  'mid_term',
  '2025-2026',
  'draft'
) RETURNING id;

-- Use the returned timetable ID to create entries
-- INSERT INTO exam_timetable_entries ...
```

---

## Performance Notes

- **Unique constraint on entries**: Prevents duplicate exams, enforced at database level (fast)
- **Indexes on date/grade/subject**: Queries are optimized for the main filtering operations
- **RLS overhead**: Minimal impact as policies use simple tenant_id checks
- **Query optimization**: Most operations use indexed columns

---

## Future Enhancements (Phase 2+)

- Paper submission tracking table
- Approval workflow automation
- Teacher auto-assignment based on teacher_subjects
- Notification system for deadlines
- Analytics and reporting

---

## Support & Questions

Refer to:
- Schema file: `E:\New folder (2)\papercraft\07112025.txt`
- Supabase docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Project documentation: See Phase 1 implementation plan

---

**Last Updated**: 2025-11-07
**Migration Version**: 1.0
**Status**: Ready for deployment
