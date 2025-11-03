# Exam Timetable System - Data Models & Relationships

## Overview

This document defines all data models for the exam timetable system, their relationships, and the workflow they support.

---

## Core Data Models

### 1. **grade_sections**
Represents the sections (A, B, C, etc.) within each grade for a specific tenant.

**Purpose**: Enables multiple sections per grade, allowing schools to have Grade 5-A, Grade 5-B, etc.

**Schema**:
```
id (uuid) - Primary key
tenant_id (uuid) - FK to tenants table
grade_id (uuid) - FK to grades table
section_name (text) - e.g., "A", "B", "C"
display_order (int) - For UI ordering
is_active (boolean) - Soft delete flag
created_at, updated_at (timestamp)
```

**Constraints**:
- Unique: (tenant_id, grade_id, section_name)
- No duplicate sections within a grade

**Usage**:
- Admin defines all sections for each grade at the start of academic year
- Example: Grade 5 has sections [A, B], Grade 6 has sections [A, B, C]

**Related Tables**:
- FK to: tenants, grades
- FK from: teacher_subjects, exam_timetable_entries

---

### 2. **teacher_subjects**
Represents the exact (Grade, Subject, Section) tuple that a teacher teaches.

**Purpose**: Replaces the cartesian product problem. Instead of teachers selecting Grade[1,2] + Subject[Maths, English] = 4 combos, they now explicitly assign exact tuples they teach.

**Schema**:
```
id (uuid) - Primary key
tenant_id (uuid) - FK to tenants
teacher_id (uuid) - FK to profiles
grade_id (uuid) - FK to grades
subject_id (uuid) - FK to subjects
section (text) - Section name (e.g., "A", "B")
academic_year (text) - e.g., "2024-2025"
is_active (boolean) - Soft delete flag
created_at, updated_at (timestamp)
```

**Constraints**:
- Unique: (tenant_id, teacher_id, grade_id, subject_id, section, academic_year)
- No duplicate assignments

**Workflow Usage**:
1. **Onboarding**: Teacher selects exact (grade, subject, section) tuples they teach
   - Example: [Grade 5-A Maths, Grade 5-B Maths, Grade 6-A Science]
2. **Paper Auto-Creation**: When timetable published, system finds all teachers with matching tuple and creates DRAFT papers

**Example Data**:
```
Anita Sharma:
  - Grade 5, Section A, Maths, 2024-2025
  - Grade 5, Section A, English, 2024-2025
  - Grade 5, Section B, Maths, 2024-2025

Rajesh Kumar:
  - Grade 6, Section A, Science, 2024-2025
  - Grade 6, Section A, Geography, 2024-2025
  - Grade 6, Section B, Science, 2024-2025
```

**Related Tables**:
- FK to: tenants, profiles (teachers), grades, subjects
- FK from: None directly (used by paper auto-creation logic)

---

### 3. **exam_calendar**
Represents planned exams for the school (yearly planning).

**Purpose**: Create a catalog of exams the school conducts so admins can plan timetables from a predefined list.

**Schema**:
```
id (uuid) - Primary key
tenant_id (uuid) - FK to tenants
exam_name (text) - e.g., "June Monthly Test"
exam_type (text) - e.g., "monthlyTest", "quarterlyTest", "finalExam"
month_number (int) - 1-12 (when this exam typically occurs)
planned_start_date (date) - Approximate start date for planning
planned_end_date (date) - Approximate end date for planning
paper_submission_deadline (date, nullable) - Soft deadline for paper creation
display_order (int) - UI ordering (1, 2, 3, etc.)
metadata (jsonb, nullable) - Future expansion (weights, max marks, etc.)
is_active (boolean) - Soft delete flag
created_at, updated_at (timestamp)
```

**Constraints**:
- Unique: (tenant_id, exam_name)
- month_number: 1-12
- planned_start_date <= planned_end_date

**Workflow Usage**:
1. **Setup**: Admin creates exam calendar once per academic year
   - Example:
     ```
     June Monthly Test (monthlyTest, month 6)
     September Quarterly Test (quarterlyTest, month 9)
     December Half-Yearly (halfYearlyTest, month 12)
     March Quarterly Test (quarterlyTest, month 3)
     May Final Exam (finalExam, month 5)
     ```
2. **Planning**: When creating timetable, admin picks from this list
3. **Daily Tests**: NOT in calendar (handled via direct timetable creation)

**Example Data**:
```
Exam Calendar for 2024-2025 academic year:

1. June Monthly Test
   - exam_type: monthlyTest
   - planned_start_date: 2024-06-15
   - planned_end_date: 2024-06-30
   - paper_submission_deadline: 2024-06-10
   - display_order: 1

2. September Quarterly Test
   - exam_type: quarterlyTest
   - planned_start_date: 2024-09-15
   - planned_end_date: 2024-09-30
   - paper_submission_deadline: 2024-09-10
   - display_order: 2

... etc
```

**Related Tables**:
- FK to: tenants
- FK from: exam_timetables (optional)

**Note**: Daily tests are NOT in exam_calendar because they're ad-hoc weekly exams created just before they happen.

---

### 4. **exam_timetables**
Represents an actual exam timetable created by admin (can be from calendar or ad-hoc).

**Purpose**: The actual timetable document created for a specific exam event. Contains metadata about the exam and its status.

**Schema**:
```
id (uuid) - Primary key
tenant_id (uuid) - FK to tenants
created_by (uuid) - FK to profiles (admin who created it)
exam_calendar_id (uuid, nullable) - FK to exam_calendar (if created from calendar)
exam_name (text) - e.g., "June Monthly Test" or "Daily Test - Week 1"
exam_type (text) - e.g., "monthlyTest", "dailyTest"
exam_number (int, nullable) - For daily tests: "week 1", "week 2", etc.
academic_year (text) - e.g., "2024-2025"
status (text) - "draft", "published", "completed", "cancelled"
published_at (timestamp, nullable) - When timetable was published
is_active (boolean) - Soft delete flag
metadata (jsonb, nullable) - Custom data per school (weights, instructions, etc.)
created_at, updated_at (timestamp)
```

**Constraints**:
- status IN ('draft', 'published', 'completed', 'cancelled')
- exam_type IN ('monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest')
- exam_calendar_id is nullable (for ad-hoc daily tests)

**Status Lifecycle**:
```
DRAFT → PUBLISHED → COMPLETED → (archived)
  ↓
  CANCELLED (if admin cancels before publishing)
```

**Workflow Usage**:
1. **Creation**: Admin creates timetable (from calendar OR ad-hoc)
2. **Editing**: Admin adds entries (grade/subject/section combinations and dates/times)
3. **Validation**: System checks if teachers assigned to all entries
4. **Publishing**: Admin publishes → papers auto-created for all teachers → notification sent
5. **Completion**: After exam is done, admin marks as completed

**Example Data**:
```
Timetable 1 (From Calendar):
- exam_name: June Monthly Test
- exam_type: monthlyTest
- exam_calendar_id: <ref to June Monthly from calendar>
- status: published
- published_at: 2024-06-10 10:00:00

Timetable 2 (Ad-hoc):
- exam_name: Daily Test - Week 1
- exam_type: dailyTest
- exam_calendar_id: NULL
- exam_number: 1
- status: draft
- published_at: NULL
```

**Related Tables**:
- FK to: tenants, profiles (created_by), exam_calendar (optional)
- FK from: exam_timetable_entries

---

### 5. **exam_timetable_entries**
Individual entries in a timetable (one per grade/subject/section combination).

**Purpose**: Defines when each grade/subject/section has their exam.

**Schema**:
```
id (uuid) - Primary key
tenant_id (uuid) - FK to tenants
timetable_id (uuid) - FK to exam_timetables
grade_id (uuid) - FK to grades
subject_id (uuid) - FK to subjects
section (text) - Section name (e.g., "A", "B")
exam_date (date) - When the exam happens
start_time (time) - Exam start time
end_time (time) - Exam end time
duration_minutes (int) - Calculated duration
is_active (boolean) - Soft delete flag
created_at, updated_at (timestamp)
```

**Constraints**:
- Unique: (timetable_id, grade_id, subject_id, section)
- No duplicate entries for same grade/subject/section in one timetable
- start_time < end_time
- duration_minutes > 0

**Workflow Usage**:
1. **Add Entries**: Admin adds entries to timetable
   ```
   Grade 5, Section A, Maths, 2024-06-15, 09:00-10:30 (90 mins)
   Grade 5, Section A, English, 2024-06-16, 09:00-10:00 (60 mins)
   ```
2. **Validation**: System finds all teachers with (Grade 5, Section A, Maths) assignment
3. **Paper Creation**: Creates DRAFT paper for each teacher
4. **Teacher Dashboard**: Teacher sees "Maths - Grade 5-A" exam paper card

**Example Data**:
```
Timetable: June Monthly Test
├─ Entry 1: Grade 5-A, Maths, 2024-06-15, 09:00-10:30
│  Teachers assigned: [Anita Sharma]
│  Papers created: 1 (for Anita Sharma)
├─ Entry 2: Grade 5-A, English, 2024-06-16, 09:00-10:00
│  Teachers assigned: [Anita Sharma]
│  Papers created: 1 (for Anita Sharma)
├─ Entry 3: Grade 5-B, Maths, 2024-06-15, 10:00-11:30
│  Teachers assigned: [Anita Sharma]
│  Papers created: 1 (for Anita Sharma)
└─ Entry 4: Grade 6-A, Science, 2024-06-20, 09:00-11:00
   Teachers assigned: [Rajesh Kumar]
   Papers created: 1 (for Rajesh Kumar)
```

**Related Tables**:
- FK to: tenants, exam_timetables, grades, subjects
- FK from: None directly (referenced by paper auto-creation logic)

---

## Relationship Diagram

```
tenants
  │
  ├─→ grades ─→ grade_sections
  │             (sections per grade)
  │
  ├─→ exam_calendar
  │   (planned exams)
  │
  ├─→ exam_timetables (created from exam_calendar OR ad-hoc)
  │   │
  │   └─→ exam_timetable_entries
  │       (grade, subject, section, date, time)
  │
  ├─→ subjects
  │   (used in teacher_subjects)
  │
  ├─→ profiles
  │   └─→ teacher_subjects
  │       (grade, subject, section, academic_year)
  │
  └─→ question_papers
      (contains section field, created from timetable entries)
```

---

## Data Flow for Paper Auto-Creation

When admin publishes a timetable, the system needs to find all teachers who should get papers:

```
1. Admin publishes timetable
   ↓
2. For each exam_timetable_entry (e.g., Grade 5-A, Maths):
   ↓
3. Query teacher_subjects:
   WHERE grade_id = Grade 5
   AND subject_id = Maths
   AND section = "A"
   AND academic_year = "2024-2025"
   AND is_active = true
   ↓
4. For each matching teacher (could be 1-N):
   ↓
5. Create DRAFT question_paper:
   {
     tenant_id: <tenant>,
     user_id: <teacher>,
     subject_id: Maths,
     grade_id: Grade 5,
     section: "A",
     exam_date: <from entry>,
     exam_type: <from timetable>,
     title: "Maths - June Monthly Test",
     status: "draft",
     questions: [],
     paper_sections: []
   }
   ↓
6. Send notification: "New paper created: Maths Grade 5-A"
   ↓
7. Paper appears in teacher's dashboard
```

---

## Edge Cases Handled

### Case 1: Multiple Teachers for Same (Grade, Subject, Section)
```
Grade 5-A Maths has 2 teachers assigned:
- Anita Sharma
- Priya Singh

When timetable published: 2 papers created (one per teacher)
```

### Case 2: No Teacher Assigned
```
Grade 5-A Science has no teacher assigned.

When publishing timetable:
✗ Validation error
"Cannot publish: No teacher assigned to Grade 5-A Science"
(Admin must assign teacher before publishing)
```

### Case 3: Teacher Unassigned Mid-Year
```
Paper exists: Maths Grade 5-A (created in June)
Teacher Anita Sharma is unassigned from Grade 5-A in September

Options (chosen: B):
✓ Paper remains visible but READ-ONLY
✓ Teacher can view historical papers but not edit
✓ Better UX than papers disappearing
```

### Case 4: Section Definition Changes
```
Grade 5 originally had sections [A, B]
Admin adds section C in September

New timetable entries can use section C
Old papers still exist for sections A, B
(No conflict because section is part of unique constraint)
```

### Case 5: Bulk Paper Creation (1800+ papers)
```
Large school, large timetable: 1800 papers to create

Solution:
- Use background job queue (async processing)
- Show progress to admin
- Send completion notification when done
- Don't block UI during creation
```

---

## Migration Path from Old System

### Current System Problems
- teacher_grade_assignments: Teachers select Grade [1, 2]
- teacher_subject_assignments: Teachers select Subject [Maths, English]
- Result: All 4 combinations assigned (cartesian product)

### Migration Strategy
1. **Phase 1**: Create grade_sections table, map existing grades to single "default" section
2. **Phase 2**: Create teacher_subjects table
3. **Phase 3**: Populate teacher_subjects from teacher_grade_assignments + teacher_subject_assignments
   - For each teacher assignment tuple, create one row per combination
4. **Phase 4**: Keep old tables for compatibility until rollover to next academic year
5. **Phase 5**: In next academic year, use only teacher_subjects (clean start)

---

## Performance Considerations

### Indexing Strategy
- `idx_teacher_subjects_teacher_id`: Fast lookup of all assignments for a teacher
- `idx_teacher_subjects_grade_subject`: Fast lookup of teachers for (grade, subject)
- `idx_exam_timetable_entries_timetable_grade_subject`: Fast lookup of entries for a subject
- `idx_exam_timetable_entries_exam_date`: Fast lookup of exams by date

### Query Optimization
For paper auto-creation (high-frequency query during publishing):
```sql
-- Find all teachers for a specific (grade, subject, section)
SELECT teacher_id
FROM teacher_subjects
WHERE grade_id = $1
  AND subject_id = $2
  AND section = $3
  AND academic_year = $4
  AND is_active = true
  AND tenant_id = $5;
```
This query uses:
- Unique constraint index for fast lookup
- 5 columns indexed: grade, subject, teacher, academic_year, tenant

### Expected Performance
- Timetable with 100 entries: ~50-100ms for all paper creation
- Timetable with 500 entries: ~200-500ms (background job recommended)
- Timetable with 1000+ entries: Use background job queue (async)

---

## Security & Multi-Tenancy

### RLS (Row Level Security) Policies
All tables have RLS enabled:
```sql
CREATE POLICY grade_sections_tenant_isolation
  USING (tenant_id = auth.jwt() ->> 'tenant_id');
```

This ensures:
- Teacher from School A cannot see School B's data
- Database-level protection (not just app-level filtering)
- Automatic enforcement for all queries

### Cascading Deletes
- grade_sections: CASCADE when grade deleted
- teacher_subjects: CASCADE when teacher/grade/subject deleted
- exam_calendar: CASCADE when tenant deleted
- exam_timetables: CASCADE when tenant deleted
- exam_timetable_entries: CASCADE when timetable deleted

### Soft Deletes
- is_active flag used for soft deletion instead of hard delete
- Preserves historical data for reports and audit
- Can recover data if needed

---

## Future Enhancements

1. **Exam Weights**: Store weightage (percentage of total marks) for each exam type
2. **Exam Retakes**: Handle re-exam scenarios with versioning
3. **Paper Review Workflow**: Approval process before students see papers
4. **Template Papers**: Save paper templates for reuse
5. **Paper Analytics**: Track paper creation patterns, difficulty distribution
6. **Scheduling Conflicts**: Detect and warn about conflicting exam times
