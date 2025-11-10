# First Migration Fix - submission_status Constraint Error

## Problem
Got error: `ERROR: 42703: column "exam_timetable_id" does not exist`

But this was actually a misleading error message from PostgreSQL about the constraint syntax in the ALTER TABLE statement.

## Root Cause
The CHECK constraint couldn't be added inline with the column definition in an ALTER TABLE statement. PostgreSQL doesn't support that syntax.

## Solution Applied

**Line 113-119** - Split into two statements:

**Before** (❌ WRONG):
```sql
ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS submission_status TEXT DEFAULT 'draft'
  CHECK (submission_status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected'));
```

**After** (✅ CORRECT):
```sql
ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS submission_status TEXT DEFAULT 'draft';

ALTER TABLE question_papers
ADD CONSTRAINT IF NOT EXISTS question_papers_submission_status_check
CHECK (submission_status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected'));
```

## Files Fixed
✅ `supabase/migrations/20251107_create_exam_tables.sql` (lines 113-119)

## Now Run

**Step 1**: In Supabase SQL Editor
1. Click **New Query**
2. Copy entire content of: `supabase/migrations/20251107_create_exam_tables.sql` (FIXED)
3. Click **Run** ▶️
4. Should succeed now ✅

**Step 2**: After Step 1 succeeds
1. Click **New Query**
2. Copy entire content of: `supabase/migrations/20251107_exam_tables_rls_policies.sql`
3. Click **Run** ▶️

Both should now complete successfully!
