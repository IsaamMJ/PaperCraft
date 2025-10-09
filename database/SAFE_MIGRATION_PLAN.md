# Safe Database Migration Plan

## ⚠️ SAFETY RULES FOR PRODUCTION DB

### Golden Rules:
1. **NEVER drop or alter existing tables**
2. **NEVER change column types on existing data**
3. **NEVER remove columns that app uses**
4. **ALWAYS use IF NOT EXISTS**
5. **ALWAYS test migrations on dev/staging first**
6. **ALWAYS have rollback plan**

---

## Current Migration Safety Analysis

### Migration 1: paper_rejection_history
**Status:** ✅ SAFE TO RUN
**Why Safe:**
- Creates NEW table (doesn't touch existing tables)
- Uses `CREATE TABLE IF NOT EXISTS` (won't fail if already exists)
- No data migration needed
- No breaking changes to existing functionality
- If it fails, app continues to work (feature just won't work)

**Risk Level:** 🟢 LOW (100% safe)

**Rollback:**
```sql
-- If needed to rollback
DROP TABLE IF EXISTS paper_rejection_history;
```

---

### Migration 2: Performance Indexes
**Status:** ✅ SAFE TO RUN
**Why Safe:**
- Only ADDS indexes (doesn't change data)
- Uses `CREATE INDEX IF NOT EXISTS` (won't fail if already exists)
- Indexes don't affect data integrity
- Queries work with or without indexes (just slower without)
- Can be created/dropped without downtime

**Risk Level:** 🟢 LOW (100% safe)

**Side Effects:**
- May take 10-30 seconds to create indexes (depends on data size)
- During index creation, queries may be slightly slower
- Uses some disk space for indexes

**Rollback:**
```sql
-- If indexes cause issues, drop them
DROP INDEX IF EXISTS idx_question_papers_tenant_status_created;
DROP INDEX IF EXISTS idx_question_papers_tenant_user_status;
-- ... etc
```

---

## Recommended Approach

### Option A: Run Now (SAFE)
Both migrations are 100% safe because:
- No existing tables modified
- No existing columns changed
- No data deleted or altered
- Uses IF NOT EXISTS everywhere
- App works fine even if migrations fail

### Option B: Test First (EXTRA SAFE)
If you want to be extra cautious:

1. **Check if table already exists:**
```sql
-- Run this first to check
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'paper_rejection_history';
```

If returns empty → Table doesn't exist, safe to create
If returns row → Table already exists, migration will skip

2. **Check existing indexes:**
```sql
-- Check what indexes exist
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'question_papers';
```

---

## Current Production Status Check

### What to verify BEFORE running migrations:

**Run these queries to understand current state:**

```sql
-- 1. Check if paper_rejection_history exists
SELECT EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name = 'paper_rejection_history'
) AS table_exists;

-- 2. Count existing papers
SELECT
  status,
  COUNT(*) as count
FROM question_papers
GROUP BY status;

-- 3. Check if any rejected papers exist
SELECT COUNT(*) as rejected_count
FROM question_papers
WHERE status = 'rejected';

-- 4. List existing indexes on question_papers
SELECT indexname
FROM pg_indexes
WHERE tablename = 'question_papers'
ORDER BY indexname;
```

---

## Migration Execution Plan

### Phase 1: Verify Current State (NOW - 2 minutes)
Run the "Current Production Status Check" queries above.
Report back what you see.

### Phase 2: Decide Based on Results
- If paper_rejection_history exists → Skip migration 1
- If indexes exist → Skip creating them again
- If rejected papers exist → Migration 1 is MORE important

### Phase 3: Execute Safe Migrations
Only run what's needed based on Phase 1.

---

## What Could Go Wrong? (Worst Case)

### Migration 1 (paper_rejection_history):
**Worst case:** Table creation fails
**Impact:** None - app continues working, reject→edit flow just won't save history
**User impact:** Zero
**Rollback:** Not needed, just try again

### Migration 2 (indexes):
**Worst case:** Index creation fails or is slow
**Impact:** Queries temporarily slower during creation (10-30 seconds)
**User impact:** Minimal - slight slowdown while creating
**Rollback:** Drop the indexes if they cause issues

---

## Conservative Approach (Recommended)

### Step 1: Check Current State First
Run these queries to see what's already there:

```sql
-- Quick health check
SELECT
  'question_papers' as table_name,
  COUNT(*) as total_rows
FROM question_papers
UNION ALL
SELECT
  'questions',
  COUNT(*)
FROM questions
UNION ALL
SELECT
  'paper_rejection_history',
  COUNT(*)
FROM paper_rejection_history;
```

If this fails on paper_rejection_history, table doesn't exist yet.

### Step 2: Report Back
Tell me:
1. Does paper_rejection_history exist?
2. How many papers do you have?
3. Any rejected papers?

Then I'll give you the exact safe commands to run.

---

## Why These Migrations Are Safe

### paper_rejection_history:
✅ New table, no impact on existing
✅ App works without it (feature degrades gracefully)
✅ Uses foreign keys properly (won't break data)
✅ RLS policies only affect new table

### Indexes:
✅ Only improve performance, don't change data
✅ Can be added/removed anytime
✅ PostgreSQL handles concurrently
✅ Uses IF NOT EXISTS (idempotent)

---

## Bottom Line

**These migrations are production-safe**, but let's check current state first to be 100% sure.

Run the "Current Production Status Check" queries and tell me what you see.
