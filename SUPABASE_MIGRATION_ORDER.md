# Supabase Migration Order - SIMPLE & CLEAR

## Run These 2 Files In This Order

---

### STEP 1️⃣ (Run First)
**File**: `supabase/migrations/20251107_create_exam_tables.sql`

**How**:
1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Click **New Query**
4. Copy-paste entire file content
5. Click **Run** ▶️
6. Wait for ✅ success message

**What it does**:
- Creates 3 new tables (exam_calendar, exam_timetables, exam_timetable_entries)
- Adds 2 columns to question_papers table
- Creates 13 indexes
- Creates 3 auto-update triggers

**Status**: ✅ Safe to run (fixed with IF NOT EXISTS)

---

### STEP 2️⃣ (Run Second)
**File**: `supabase/migrations/20251107_exam_tables_rls_policies.sql`

**How**:
1. In Supabase SQL Editor
2. Click **New Query** (again)
3. Copy-paste entire file content
4. Click **Run** ▶️
5. Wait for ✅ success message

**What it does**:
- Enables RLS (Row Level Security)
- Creates 15 security policies
- Ensures tenant data isolation
- Restricts admin-only access

**Status**: ✅ Fixed (column references corrected)

---

## That's It! ✅

Both migrations complete → Database ready → Move to Task 3

---

## Verification (Optional)

After both run successfully, copy-paste this into a NEW QUERY to verify:

```sql
-- Check all 3 tables exist
SELECT table_name FROM information_schema.tables
WHERE table_name IN ('exam_calendar', 'exam_timetables', 'exam_timetable_entries')
ORDER BY table_name;
```

Should return:
- exam_calendar
- exam_timetable_entries
- exam_timetables

---

## Safety Confirmation ✅

- ✅ Won't affect live teachers
- ✅ Won't delete existing data
- ✅ Zero downtime
- ✅ Can be run multiple times safely
- ✅ Backward compatible

---

## Files Location

Both files are in: `supabase/migrations/`

```
✅ supabase/migrations/20251107_create_exam_tables.sql          [RUN 1ST]
✅ supabase/migrations/20251107_exam_tables_rls_policies.sql    [RUN 2ND]
```

---

**Ready?** Start with Step 1️⃣
