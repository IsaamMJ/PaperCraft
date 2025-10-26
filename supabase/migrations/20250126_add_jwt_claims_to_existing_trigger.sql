-- Add JWT claims update to existing user registration trigger
-- This migration modifies the existing handle_new_user_registration function
-- to also populate JWT claims with tenant_id and role for RLS policies

-- ============================================================================
-- UPDATE: handle_new_user_registration function
-- ============================================================================
-- This function already exists and creates profiles on auth signup
-- We need to add JWT claims update to it

CREATE OR REPLACE FUNCTION public.handle_new_user_registration()
RETURNS TRIGGER AS $$
DECLARE
  user_domain TEXT;
  default_role TEXT;
  assigned_tenant_id UUID;
  tenant_name TEXT;
BEGIN
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email address is required for registration';
  END IF;

  user_domain := LOWER(split_part(NEW.email, '@', 2));

  IF user_domain = 'pearlmatricschool.com' THEN
    default_role := 'teacher';
  ELSIF user_domain = 'gmail.com' THEN
    default_role := 'admin';
  ELSE
    default_role := 'user';
  END IF;

  IF user_domain = 'pearlmatricschool.com' THEN
    SELECT id INTO assigned_tenant_id
    FROM public.tenants
    WHERE domain = user_domain AND is_active = true
    LIMIT 1;

    IF assigned_tenant_id IS NULL THEN
      RAISE EXCEPTION 'No active tenant found for domain: %', user_domain;
    END IF;

  ELSIF user_domain = 'gmail.com' THEN
    tenant_name := COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    ) || '''s Workspace (' || substring(NEW.id::TEXT from 1 for 8) || ')';

    INSERT INTO public.tenants (name, domain, is_active)
    VALUES (tenant_name, NULL, true)
    RETURNING id INTO assigned_tenant_id;

  ELSE
    RAISE EXCEPTION 'Unauthorized email domain: %', user_domain;
  END IF;

  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    tenant_id,
    role,
    is_active,
    last_login_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    assigned_tenant_id,
    default_role,
    true,
    NOW()
  );

  -- ✅ NEW: Update JWT claims so RLS policies work
  -- Store tenant_id and role in raw_app_meta_data
  -- Supabase automatically includes these in auth.jwt()
  UPDATE auth.users
  SET raw_app_meta_data =
    COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
      'tenant_id', assigned_tenant_id::text,
      'role', default_role
    )
  WHERE id = NEW.id;

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Profile creation failed for user %: %', NEW.id, SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- CREATE: Trigger to update JWT claims when profile is updated by admins
-- ============================================================================
-- When an admin updates a user's profile (e.g., changes role or tenant)
-- we need to sync those changes to the JWT claims

CREATE OR REPLACE FUNCTION public.update_jwt_claims_on_profile_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update JWT claims if tenant_id or role changed
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR NEW.role IS DISTINCT FROM OLD.role THEN
    UPDATE auth.users
    SET raw_app_meta_data =
      COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
        'tenant_id', NEW.tenant_id::text,
        'role', NEW.role
      )
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error updating JWT claims for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the trigger if it already exists
DROP TRIGGER IF EXISTS on_profile_updated_sync_jwt ON profiles;

-- Create the trigger on the profiles table
CREATE TRIGGER on_profile_updated_sync_jwt
  AFTER UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_jwt_claims_on_profile_update();

-- ============================================================================
-- UPDATE: All existing users with JWT claims from their profiles
-- ============================================================================
-- For any users that were created before this migration,
-- we need to populate their JWT claims from their existing profile data

UPDATE auth.users
SET raw_app_meta_data =
  COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
    'tenant_id', (SELECT tenant_id::text FROM profiles WHERE profiles.id = auth.users.id),
    'role', (SELECT role FROM profiles WHERE profiles.id = auth.users.id)
  )
WHERE id IN (
  SELECT id FROM profiles
  WHERE tenant_id IS NOT NULL
  AND id NOT IN (
    -- Don't update if JWT claims already exist
    SELECT id FROM auth.users
    WHERE raw_app_meta_data->>'tenant_id' IS NOT NULL
  )
);

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- What this migration does:
--
-- 1. UPDATES handle_new_user_registration() function:
--    - Keeps all existing logic (domain checking, tenant creation)
--    - ADDS: Update auth.users.raw_app_meta_data with tenant_id and role
--    - Result: New users get JWT claims on signup
--
-- 2. CREATES update_jwt_claims_on_profile_update() function:
--    - Fires when admin updates a profile's tenant_id or role
--    - Syncs changes to auth.users.raw_app_meta_data
--    - Result: JWT claims stay in sync with profile
--
-- 3. CREATES on_profile_updated_sync_jwt trigger:
--    - Calls the update function when profiles are updated
--
-- 4. UPDATES all existing users:
--    - Sets JWT claims from their profile data
--    - Only updates users without existing JWT claims
--    - Result: Old users can access data after login
--
-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After running this, verify with:
--
-- SELECT id, email, raw_app_meta_data->>'tenant_id' as tenant_id_in_jwt
-- FROM auth.users LIMIT 5;
--
-- Should show tenant_id populated in the JWT claims
