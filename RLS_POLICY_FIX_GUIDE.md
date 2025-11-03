# RLS Policy Fix Guide

## Issue: "new row violates row level security policy"

You're encountering a Row Level Security (RLS) violation when trying to create sections (or grades/subjects) in the admin setup wizard.

### Root Cause

The RLS policies created in the exam timetable migration (`20251101_add_exam_timetable_schema.sql`) are too restrictive:

```sql
CREATE POLICY grade_sections_tenant_isolation ON public.grade_sections
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');
```

**Problems with this policy:**
1. Uses `FOR ALL` with only `USING` clause - doesn't properly handle INSERT operations
2. Checks JWT claims that might not be properly set in your auth token
3. Doesn't use the `user_roles` table verification that we established in other migrations

### Solution

Two new migration files have been created to fix this:

1. **20251103_fix_grade_sections_rls_policy.sql** - Fixes `grade_sections` table
2. **20251103_fix_subjects_rls_policy.sql** - Fixes `subjects` table

These migrations:
- Drop the restrictive `FOR ALL` policy
- Create separate policies for SELECT, INSERT, UPDATE, DELETE operations
- Use the `user_roles` table to verify admin role (reliable method)
- Allow admins to perform all operations (INSERT, UPDATE, DELETE)
- Allow regular users to only SELECT data for their tenant

### How to Apply the Fix

**Option 1: Using Supabase Dashboard (Recommended)**

1. Go to your Supabase project
2. Navigate to SQL Editor
3. Copy and paste the contents of each migration file:
   - `supabase/migrations/20251103_fix_grade_sections_rls_policy.sql`
   - `supabase/migrations/20251103_fix_subjects_rls_policy.sql`
4. Run each SQL script

**Option 2: Using Supabase CLI**

```bash
supabase db push  # This will apply all pending migrations
```

**Option 3: Quick Fix (if you want to test immediately)**

If you want to test the admin setup quickly while you prepare the migrations, you can temporarily disable RLS on the `grade_sections` and `subjects` tables:

```sql
-- Temporarily disable RLS for testing only
ALTER TABLE public.grade_sections DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects DISABLE ROW LEVEL SECURITY;

-- Re-enable after testing is complete
ALTER TABLE public.grade_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
```

### After Applying the Fix

Once you apply these migrations:
1. Your admin user should be able to create grades, sections, and subjects
2. The DELETE-then-INSERT pattern will work without RLS violations
3. Regular users will still be properly isolated to their tenant data

### Verification

To verify the fix is working:
1. Log in as an admin user
2. Go through the admin setup wizard
3. Try completing each step (grades → sections → subjects)
4. The "Complete Setup" button should save without RLS errors

