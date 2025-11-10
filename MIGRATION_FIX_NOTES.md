# Migration Fix - Index Already Exists Error

## Problem
When running the migration `20251107_create_exam_tables.sql`, you got:
```
ERROR: 42P07: relation "idx_exam_timetables_academic_year" already exists
```

This happens because the migration was partially run before or indexes already exist.

## Solution Applied
Updated the migration file to be **idempotent** (safe to run multiple times):

### Changes Made:

1. **All CREATE INDEX statements** - Added `IF NOT EXISTS`
   ```sql
   -- Before
   CREATE INDEX idx_exam_calendar_tenant ON exam_calendar(tenant_id);

   -- After
   CREATE INDEX IF NOT EXISTS idx_exam_calendar_tenant ON exam_calendar(tenant_id);
   ```

   This applies to all 13 indexes in the migration.

2. **Triggers** - Changed to drop-and-recreate pattern
   ```sql
   -- Before
   CREATE TRIGGER exam_calendar_updated_at BEFORE UPDATE ON exam_calendar...

   -- After
   DROP TRIGGER IF EXISTS exam_calendar_updated_at ON exam_calendar;
   CREATE TRIGGER exam_calendar_updated_at BEFORE UPDATE ON exam_calendar...
   ```

## How to Re-run the Migration

Now you can safely run the migration again:

1. Open Supabase Dashboard
2. SQL Editor → New Query
3. Copy entire content of: `supabase/migrations/20251107_create_exam_tables.sql` (updated version)
4. Click **Run** ▶️
5. It should complete successfully now ✅

## What This Means
- ✅ You can run this migration multiple times without errors
- ✅ If partially applied before, running again will complete it
- ✅ No data loss
- ✅ Safe for live production environment

## Next Steps

1. Run the updated migration file
2. Then run: `supabase/migrations/20251107_exam_tables_rls_policies.sql`

Both should now complete without errors!

## Files Updated
- `supabase/migrations/20251107_create_exam_tables.sql` ✅ Fixed
- (No changes needed to RLS policies migration - already uses `IF NOT EXISTS`)

---
**Status**: Ready to re-run
**Date**: 2025-11-07
