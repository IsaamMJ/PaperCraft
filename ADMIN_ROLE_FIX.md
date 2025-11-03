# Admin Role Assignment Fix

## Issue
Still getting "new row violates row-level security policy" on `grade_sections` table.

## Root Cause
Your user account is likely logged in as a **teacher** instead of **admin**.

### How Roles Are Assigned:
1. **Gmail users** (gmail.com) → `admin` role
2. **School domain users** (@pearlmatricschool.com) → `teacher` role
3. **Other users** → `user` role

### Your Case:
If you logged in with `@pearlmatricschool.com`, you got `teacher` role.
Teachers cannot create sections (only admins can).

## Solution: Manually Update Your Role to Admin

### Step 1: Go to Supabase Dashboard

1. Open your Supabase project
2. Navigate to **SQL Editor**
3. Run this query to check your current role:

```sql
SELECT id, email, role, tenant_id 
FROM public.profiles 
WHERE email = 'your-email@pearlmatricschool.com'
LIMIT 1;
```

Replace `your-email@pearlmatricschool.com` with your actual email.

### Step 2: Update Role to Admin

If you're the school admin, run this query:

```sql
-- Update your role to admin
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'your-email@pearlmatricschool.com';

-- Also update JWT claims in auth.users
UPDATE auth.users
SET raw_app_meta_data = 
  COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
WHERE email = 'your-email@pearlmatricschool.com';
```

### Step 3: Log Out and Log Back In

1. Log out of the app completely
2. Log back in
3. Your JWT token will now have `role: 'admin'`
4. Try the admin setup wizard again

## Alternative: Create an Admin User

If you want a separate admin account, create one with Gmail:

1. Register a new account with your Gmail (gmail.com)
2. You'll automatically get `admin` role
3. Use that account for admin setup wizard
4. Keep your school email for teacher access

## Verification

To verify the role was updated:

```sql
-- Check profiles table
SELECT email, role, tenant_id FROM public.profiles WHERE email = 'your-email@pearlmatricschool.com';

-- Check JWT claims in auth.users
SELECT email, raw_app_meta_data->>'role' as jwt_role 
FROM auth.users 
WHERE email = 'your-email@pearlmatricschool.com';
```

Both should show `admin` role.

