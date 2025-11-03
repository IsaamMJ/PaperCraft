# JWT Claims Fix for Admin User

## Issue
- Your profile IS admin in the database
- BUT your current JWT token doesn't have the admin role claim
- The RLS policy checks auth.jwt() ->> 'role' which returns null or 'teacher'

## Root Cause
Your account was created BEFORE we added the JWT claims update mechanism.
The JWT claims in auth.users.raw_app_meta_data were never populated.

## Solution

### Step 1: Verify Current JWT Claims
Run this in Supabase SQL Editor:

```sql
SELECT 
  email,
  raw_app_meta_data->>'role' as jwt_role,
  raw_app_meta_data->>'tenant_id' as jwt_tenant_id
FROM auth.users
WHERE email = 'papercraft@pearlmatricschool.com';
```

If `jwt_role` is NULL or 'teacher', proceed to Step 2.

### Step 2: Update JWT Claims

Run this in Supabase SQL Editor:

```sql
UPDATE auth.users
SET raw_app_meta_data = 
  COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
    'role', 'admin',
    'tenant_id', (SELECT tenant_id::text FROM public.profiles WHERE email = 'papercraft@pearlmatricschool.com')
  )
WHERE email = 'papercraft@pearlmatricschool.com';
```

### Step 3: Force Log Out and Log Back In

This is **CRITICAL** - your current session has an old JWT token.

1. Close the app completely (don't just navigate away)
2. Log out if you get the chance
3. Log back in
4. The new login will get a fresh JWT token with the admin role

### Step 4: Try Admin Setup Again

Now try creating sections - it should work!

