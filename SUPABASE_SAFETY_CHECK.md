# Supabase Safety Check - Before Running Migrations

Run these queries in your Supabase SQL Editor to verify the current state before deploying the migrations. This will help us ensure the migrations won't crash your setup.

## 1. Check for Existing User Profile Trigger

Run this query to see if the `on_auth_user_created` trigger already exists:

```sql
SELECT
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created'
OR trigger_name LIKE '%handle_new_user%';
```

**Expected Result:**
- If empty: Trigger doesn't exist (safe to create)
- If it returns rows: Trigger already exists (we need to check what it does)

---

## 2. Check for Existing JWT Claims Trigger

Run this query to see if the `on_profile_updated` trigger exists:

```sql
SELECT
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_profile_updated'
OR trigger_name LIKE '%update_jwt_claims%';
```

**Expected Result:**
- If empty: Trigger doesn't exist (safe to create)
- If it returns rows: Trigger already exists (we need to check what it does)

---

## 3. Check for Functions in Public Schema

Run this query to see what functions already exist:

```sql
SELECT
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (routine_name = 'handle_new_user'
  OR routine_name = 'update_jwt_claims')
ORDER BY routine_name;
```

**Expected Result:**
- If empty: Functions don't exist (safe to create)
- If it returns rows: Functions already exist (we need to check them)

---

## 4. Check All Triggers on Auth.Users and Profiles Tables

Run this query to see ALL triggers on these important tables:

```sql
SELECT
  trigger_name,
  event_object_table,
  event_manipulation,
  trigger_timing
FROM information_schema.triggers
WHERE event_object_table IN ('users', 'profiles')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

**Expected Result:**
This will show us all existing triggers so we can see the current state.

---

## 5. Check Current RLS Policies

Run this query to see what RLS policies exist on the profiles table:

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;
```

**Expected Result:**
This shows the current RLS setup. We should see policies like:
- `profiles_select_consolidated`
- `profiles_update_consolidated`

---

## 6. Check Profiles Table Structure

Run this query to verify the profiles table has the expected columns:

```sql
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;
```

**Expected Result:**
Should have columns like: `id`, `email`, `full_name`, `tenant_id`, `role`, `is_active`, `created_at`, `updated_at`

---

## 7. Check Auth.Users Table Structure

Run this query to see what columns exist in auth.users (for JWT setup):

```sql
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth'
AND table_name = 'users'
ORDER BY ordinal_position;
```

**Expected Result:**
Should have columns including: `id`, `email`, `raw_user_meta_data`, `raw_app_meta_data`

---

## 8. Check for Existing Profile Records

Run this query to see if profiles already exist for your auth users:

```sql
SELECT
  COUNT(*) as total_auth_users,
  (SELECT COUNT(*) FROM profiles) as total_profiles,
  COUNT(*) - (SELECT COUNT(*) FROM profiles) as missing_profiles
FROM auth.users;
```

**Expected Result:**
This shows if there are auth users without profiles (which would indicate the trigger doesn't exist or isn't working).

---

## How to Interpret Results

### Safe to Deploy If:
- ✅ Both triggers don't exist (queries 1 & 2 return empty)
- ✅ Both functions don't exist (query 3 returns empty)
- ✅ Profiles table has the expected columns (query 6)
- ✅ Auth.users table has the expected columns (query 7)

### Needs Caution If:
- ⚠️ Triggers already exist (query 1 or 2 returns rows)
- ⚠️ Functions already exist (query 3 returns rows)
- ⚠️ Profiles table is missing columns
- ⚠️ Many auth users have no corresponding profiles (query 8)

### Would NOT Crash Because:
1. **Migration uses `DROP ... IF EXISTS`** - Won't error if trigger doesn't exist
2. **Migration uses `CREATE OR REPLACE`** - Won't error if function exists (just replaces it)
3. **Migration has `EXCEPTION WHEN OTHERS`** - Errors are caught and logged

---

## What to Do After Running Queries

1. **Run all 8 queries** in your Supabase SQL Editor
2. **Copy the results** and share them with me
3. **I'll verify** that the migrations are safe to run
4. **I can also create a safer version** if needed (with more careful handling)

---

## Safe Approach

If you're worried about risk:

1. **Create a database backup** in Supabase (takes 1-2 minutes)
2. **Run the safety check queries** to see current state
3. **Share results** so I can verify
4. **I'll give you the go-ahead** before you run the migrations

The migrations have built-in safety:
- `IF EXISTS` clauses prevent errors
- Exception handling prevents crashes
- They just create/update, not delete anything

---

## Quick Copy-Paste Bundle

If you want to run all at once, here's the complete script:

```sql
-- Run all safety checks
SELECT 'Checking for on_auth_user_created trigger...' as check_name;
SELECT
  trigger_name,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created' OR trigger_name LIKE '%handle_new_user%';

SELECT 'Checking for on_profile_updated trigger...' as check_name;
SELECT
  trigger_name,
  event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'on_profile_updated' OR trigger_name LIKE '%update_jwt_claims%';

SELECT 'Checking for functions...' as check_name;
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (routine_name = 'handle_new_user' OR routine_name = 'update_jwt_claims');

SELECT 'All triggers on important tables...' as check_name;
SELECT
  trigger_name,
  event_object_table,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table IN ('users', 'profiles')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

SELECT 'RLS policies on profiles...' as check_name;
SELECT
  policyname,
  permissive,
  roles
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

SELECT 'Profiles table structure...' as check_name;
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

SELECT 'Auth users vs profiles count...' as check_name;
SELECT
  COUNT(*) as total_auth_users,
  (SELECT COUNT(*) FROM profiles) as total_profiles,
  COUNT(*) - (SELECT COUNT(*) FROM profiles) as missing_profiles
FROM auth.users;
```

Copy all the `SELECT` statements above and run them in your Supabase SQL Editor to get the current state.
