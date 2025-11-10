# RLS Policy Fix - Column Reference Error

## Problem

When running the RLS policies migration `20251107_exam_tables_rls_policies.sql`, you got:
```
ERROR: 42703: column "exam_timetable_id" does not exist
```

This occurred at lines 191 and 226 in the RLS policies file.

## Root Cause

In PostgreSQL RLS policies, when referencing columns from the table being secured within a subquery, you must use the **table alias** to disambiguate which table's column you're referencing.

The policies had:
```sql
WHERE id = exam_timetable_id  -- ❌ WRONG - column reference is ambiguous
```

But should have been:
```sql
WHERE id = exam_timetable_entries.exam_timetable_id  -- ✅ CORRECT
```

## Solution Applied

Updated both INSERT and UPDATE policies for `exam_timetable_entries`:

1. **Line 191** - INSERT policy `exam_timetable_entries_insert_admin_only`
   - Changed: `WHERE id = exam_timetable_id`
   - To: `WHERE id = exam_timetable_entries.exam_timetable_id`

2. **Line 226** - UPDATE policy `exam_timetable_entries_update_admin_only`
   - Changed: `WHERE id = exam_timetable_id`
   - To: `WHERE id = exam_timetable_entries.exam_timetable_id`

## Files Fixed

- ✅ `supabase/migrations/20251107_exam_tables_rls_policies.sql`

## How to Re-run

Now you can safely run the RLS policies migration:

1. Open Supabase Dashboard → SQL Editor
2. Click **"New Query"**
3. Copy entire content of: `supabase/migrations/20251107_exam_tables_rls_policies.sql` (updated version)
4. Click **"Run"** ▶️
5. Should complete successfully now ✅

## Migration Order

1. ✅ **First**: `supabase/migrations/20251107_create_exam_tables.sql` (already applied)
2. ✅ **Second**: `supabase/migrations/20251107_exam_tables_rls_policies.sql` (FIXED - apply now)

---

**Status**: Ready to re-run
**Date**: 2025-11-07
**Impact**: Zero impact on live teachers or existing data
