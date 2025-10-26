# Get ALL Triggers and Functions from Supabase

Use these queries to see everything in your database. Run them in your Supabase SQL Editor.

---

## 1. GET ALL TRIGGERS (Complete Details)

```sql
SELECT
  trigger_schema,
  trigger_name,
  event_object_schema,
  event_object_table,
  event_manipulation,
  action_timing,
  action_orientation,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY event_object_table, trigger_name;
```

This will show you:
- **trigger_schema**: Which schema the trigger is in (usually 'public')
- **trigger_name**: Name of the trigger
- **event_object_table**: Which table the trigger is on
- **event_manipulation**: When it fires (INSERT, UPDATE, DELETE)
- **action_statement**: The PostgreSQL function it calls

---

## 2. GET ALL FUNCTIONS (Complete Details)

```sql
SELECT
  routine_schema,
  routine_name,
  routine_type,
  data_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema NOT IN ('pg_catalog', 'information_schema', 'net', 'pgsodium')
ORDER BY routine_schema, routine_name;
```

This will show you:
- **routine_schema**: Schema the function is in
- **routine_name**: Function name
- **routine_type**: FUNCTION or PROCEDURE
- **data_type**: What it returns
- **routine_definition**: The actual SQL code

---

## 3. GET ALL TRIGGERS - SIMPLER FORMAT

If the above is too much info, use this simpler version:

```sql
SELECT
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

---

## 4. GET ALL FUNCTIONS - SIMPLER FORMAT

Simpler function query:

```sql
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

---

## 5. GET TRIGGERS ON SPECIFIC TABLES

If you want to see triggers only on important tables:

```sql
SELECT
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table IN (
  'profiles',
  'auth.users',
  'question_papers',
  'teacher_grade_assignments',
  'teacher_subject_assignments'
)
ORDER BY event_object_table, trigger_name;
```

---

## 6. GET ALL FUNCTIONS WITH THEIR DEFINITIONS

This shows the actual code of each function:

```sql
SELECT
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

---

## 7. QUICK OVERVIEW - COUNT OF TRIGGERS AND FUNCTIONS

Get a summary:

```sql
SELECT
  'Triggers' as type,
  COUNT(*) as count
FROM information_schema.triggers
WHERE trigger_schema = 'public'
UNION ALL
SELECT
  'Functions' as type,
  COUNT(*) as count
FROM information_schema.routines
WHERE routine_schema = 'public';
```

---

## 8. LIST ALL TRIGGERS WITH FULL DETAILS (FORMATTED)

Most complete, readable format:

```sql
SELECT
  format(
    E'TABLE: %s\nTRIGGER: %s\nWHEN: %s %s\nFUNCTION: %s',
    event_object_table,
    trigger_name,
    action_timing,
    event_manipulation,
    action_statement
  ) as trigger_details
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

---

## Which Query to Run?

**For Maximum Information:** Run Query #1 and #2

**For Quick Check:** Run Query #7

**For Just Seeing Names:** Run Query #3 and #4

---

## Copy-Paste All At Once

Run all of these together to get a complete picture:

```sql
-- ============== SUMMARY ==============
SELECT 'SUMMARY' as section;
SELECT
  'Triggers' as type,
  COUNT(*) as count
FROM information_schema.triggers
WHERE trigger_schema = 'public'
UNION ALL
SELECT
  'Functions' as type,
  COUNT(*) as count
FROM information_schema.routines
WHERE routine_schema = 'public';

-- ============== ALL TRIGGERS ==============
SELECT 'ALL TRIGGERS' as section;
SELECT
  trigger_name,
  event_object_table,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============== ALL FUNCTIONS ==============
SELECT 'ALL FUNCTIONS' as section;
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;

-- ============== TRIGGERS WITH CODE ==============
SELECT 'TRIGGERS WITH DETAILS' as section;
SELECT
  trigger_name,
  event_object_table,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ============== FUNCTIONS WITH CODE ==============
SELECT 'FUNCTIONS WITH CODE' as section;
SELECT
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

---

## What to Look For

After running, search the results for:

**Triggers I created:**
- ✓ `on_auth_user_created` (should NOT exist yet)
- ✓ `on_profile_updated` (should NOT exist yet)

**Functions I created:**
- ✓ `handle_new_user` (should NOT exist yet)
- ✓ `update_jwt_claims` (should NOT exist yet)

**Other triggers/functions:**
- `trigger_increment_paper_version` (mentioned in migrations, OK if exists)
- Any others related to your business logic

---

## Next Steps

1. Copy one of the queries above
2. Paste into Supabase SQL Editor
3. Run it
4. Share the results with me
5. I'll verify if migrations are safe to run
