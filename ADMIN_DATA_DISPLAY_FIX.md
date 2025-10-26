# Admin Console Data Display Issues - Root Cause Analysis & Fix

## Issue Summary

The admin console was showing "Created by User" instead of the actual teacher's name, and teacher/user lists in admin settings were not showing data from the same tenant.

### Affected Areas:
1. **Admin Dashboard** - Paper cards showed "Created by User"
2. **Teacher Assignment Management** - No teachers displayed in the list
3. **Manage Users** - No users displayed in the list

## Root Cause Analysis

### The Problem Chain

1. **Missing Database Trigger**
   - When users sign up via OAuth (Google), Supabase creates an `auth.users` record
   - But the application's `profiles` table had no record created for the new user
   - The code in `auth_data_source.dart` calls `_waitForProfileCreation()` expecting a database trigger to create the profile
   - Without the trigger, this wait times out, and the fetch fails
   - The fallback is to show "User" instead of the actual name

2. **Missing JWT Claims**
   - RLS policies use `auth.jwt()->>'tenant_id'` to enforce tenant isolation
   - But the JWT token didn't have `tenant_id` in its custom claims
   - Even if the profile existed, queries were blocked by RLS because the JWT didn't contain the tenant context
   - The RLS policy: `tenant_id = (select auth.jwt()->>'tenant_id')::uuid` would fail

3. **Data Fetching Falls Back to "User"**
   - When `UserInfoService.getUserFullName(userId)` tries to fetch a user profile
   - It calls `_authUseCase.getUserById(userId)`
   - This calls `AuthDataSource._getUserProfile(userId)`
   - If the query fails (either because profile doesn't exist OR RLS blocks it)
   - The fallback logic returns 'User' (line 61, 83, 99 in user_info_service.dart)

## The Fix

### Part 1: Create User Profile Trigger

**File:** `supabase/migrations/20250126_create_user_profile_trigger.sql`

Creates a PostgreSQL function and trigger that:
- Fires AFTER a new user is inserted into `auth.users` (OAuth signup)
- Automatically creates a corresponding `profiles` table record
- Sets `tenant_id` from user metadata (if provided during signup)
- Sets default role to 'teacher'
- Handles errors gracefully without breaking auth

**Key Code:**
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id, email, full_name, tenant_id, role, is_active, created_at, updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    CASE
      WHEN NEW.raw_user_meta_data->>'tenant_id' IS NOT NULL
      THEN (NEW.raw_user_meta_data->>'tenant_id')::uuid
      ELSE NULL
    END,
    COALESCE(NEW.raw_user_meta_data->>'role', 'teacher'),
    true,
    NOW(),
    NOW()
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

### Part 2: Setup JWT Custom Claims

**File:** `supabase/migrations/20250126_setup_jwt_custom_claims.sql`

Creates functions and triggers to:
- Automatically update JWT claims whenever a profile is created or updated
- Stores `tenant_id` and `role` in `auth.users.raw_app_meta_data`
- Supabase automatically includes these in the JWT token for all authenticated requests
- RLS policies can then check `auth.jwt()->>'tenant_id'` and `auth.jwt()->>'role'`

**Key Code:**
```sql
CREATE OR REPLACE FUNCTION public.update_jwt_claims()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE auth.users
  SET raw_app_meta_data =
    COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
      'tenant_id', NEW.tenant_id::text,
      'role', NEW.role
    )
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_updated
  AFTER INSERT OR UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_jwt_claims();
```

Also updates all existing users:
```sql
UPDATE auth.users
SET raw_app_meta_data =
  COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
    'tenant_id', (SELECT tenant_id::text FROM profiles WHERE profiles.id = auth.users.id),
    'role', (SELECT role FROM profiles WHERE profiles.id = auth.users.id)
  )
WHERE id IN (SELECT id FROM profiles WHERE tenant_id IS NOT NULL);
```

## How This Fixes the Issues

### Issue #1: Admin Dashboard showing "Created by User"

**Before:**
1. User signs up via OAuth
2. No trigger creates profile → no profile record exists
3. `UserInfoService.getUserFullName(userId)` tries to fetch the profile
4. Query fails (no profile exists or RLS blocks it)
5. Falls back to returning 'User'

**After:**
1. User signs up via OAuth
2. Trigger automatically creates profile record with tenant_id
3. JWT claims are updated with tenant_id and role
4. `UserInfoService.getUserFullName(userId)` succeeds
5. Returns actual full name from profile

**Affected Code Paths:**
- `admin_dashboard_page.dart` lines 654-666: Now receives actual user name instead of 'User'
- `user_info_service.dart` line 43: Successfully fetches user via `_authUseCase.getUserById(userId)`

### Issue #2: Teacher Assignment not showing teachers

**Before:**
1. Admin tries to load teachers via `UserManagementBloc.LoadUsers()`
2. Calls `UserRepository.getTenantUsers(tenantId)`
3. Queries `profiles` table with `tenant_id` filter
4. RLS policy blocks query because JWT doesn't have tenant_id claim
5. Returns empty list

**After:**
1. Admin loads teachers via `UserManagementBloc.LoadUsers()`
2. Calls `UserRepository.getTenantUsers(tenantId)`
3. Queries `profiles` table with `tenant_id` filter
4. RLS policy passes because JWT now contains tenant_id claim matching the filter
5. Returns all teachers in the tenant

**Affected Code Paths:**
- `user_management_bloc.dart` line 112: Successfully fetches tenant users
- `user_data_source.dart` line 29-36: Query now passes RLS policy

### Issue #3: Manage Users not showing users

**Same mechanism as Issue #2** - the same data source query is used for both teachers and users.

## Data Flow After Fix

```
1. User Signs Up (OAuth)
   ↓
2. auth.users record created by Supabase
   ↓
3. handle_new_user() trigger fires
   ↓
4. Creates profiles record with tenant_id from metadata
   ↓
5. on_profile_updated() trigger fires
   ↓
6. Updates auth.users.raw_app_meta_data with tenant_id & role
   ↓
7. Supabase includes these claims in JWT token
   ↓
8. Auth flow calls _waitForProfileCreation() - now succeeds (profile exists)
   ↓
9. User authenticated with full profile data
   ↓
10. All queries that check auth.jwt()->>'tenant_id' now work
    - Admin dashboard fetches creator names
    - Teacher assignment shows teachers
    - Manage users shows users from tenant
```

## RLS Policy Checks

The existing RLS policies now work correctly:

```sql
-- profiles_select_consolidated policy
CREATE POLICY "profiles_select_consolidated" ON profiles
  FOR SELECT
  USING (
    (select auth.uid()) = id  -- User can view own profile
    OR
    tenant_id = (select auth.jwt()->>'tenant_id')::uuid  -- User can view tenant members
  );

-- Now both conditions work:
-- 1. Checking own profile: auth.uid() = id ✓
-- 2. Checking tenant members: jwt claims now have tenant_id ✓
```

## Files Modified/Created

### Created Files:
1. `supabase/migrations/20250126_create_user_profile_trigger.sql` - User profile creation trigger
2. `supabase/migrations/20250126_setup_jwt_custom_claims.sql` - JWT claims setup
3. `ADMIN_DATA_DISPLAY_FIX.md` - This documentation (Git ignored or tracked)

### No Changes Required To:
- `auth_data_source.dart` - Works as designed once trigger exists
- `user_info_service.dart` - Works as designed once profiles can be fetched
- `admin_dashboard_page.dart` - Works as designed
- `user_management_bloc.dart` - Works as designed
- RLS policies - Already correct in `fix_rls_performance_CORRECT.sql`

## Deployment Steps

1. **In Supabase Console:**
   - Go to SQL Editor
   - Copy and execute `supabase/migrations/20250126_create_user_profile_trigger.sql`
   - Copy and execute `supabase/migrations/20250126_setup_jwt_custom_claims.sql`

2. **For Existing Users:**
   - The second migration updates all existing user JWT claims
   - Users will have updated JWT tokens on their next login

3. **For New Users:**
   - They'll automatically get profile records and JWT claims from the triggers

## Verification

After deploying the migrations:

1. **Create a test user** via OAuth signup
2. **Check in Supabase:**
   - Query `profiles` table - should have a new record with tenant_id
   - Query `auth.users` - should have tenant_id in raw_app_meta_data

3. **Check in App:**
   - Admin dashboard paper cards show actual creator names (not "User")
   - Teacher assignment shows list of teachers from same tenant
   - Manage users shows list of users from same tenant

## Related Code References

- `lib/features/authentication/data/datasources/auth_data_source.dart:176-236` - Profile creation retry logic
- `lib/features/authentication/data/datasources/user_data_source.dart:23-66` - getTenantUsers() with tenant_id filter
- `lib/features/paper_workflow/domain/services/user_info_service.dart:21-101` - getUserFullName() with caching
- `lib/features/admin/presentation/pages/admin_dashboard_page.dart:654-666` - Paper card creator display
- `lib/features/paper_workflow/presentation/bloc/user_management_bloc.dart:100-121` - User loading logic
- `supabase/migrations/fix_rls_performance_CORRECT.sql:17-37` - RLS policies using JWT claims
