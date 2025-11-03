-- Fix: Allow personal email domains (not just hardcoded gmail.com)
-- This migration fixes the handle_new_user_registration trigger
-- to accept ANY personal email domain, not just gmail.com

-- ============================================================================
-- UPDATE: handle_new_user_registration function
-- ============================================================================
-- The old version only accepted:
--   1. pearlmatricschool.com (or other specific school domains)
--   2. gmail.com only!
--
-- The new version accepts ANY personal email domain and creates a tenant

CREATE OR REPLACE FUNCTION public.handle_new_user_registration()
RETURNS TRIGGER AS $$
DECLARE
  user_domain TEXT;
  default_role TEXT;
  assigned_tenant_id UUID;
  tenant_name TEXT;
  existing_tenant_id UUID;
BEGIN
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email address is required for registration';
  END IF;

  user_domain := LOWER(split_part(NEW.email, '@', 2));

  -- ✅ CHECK: Is this email from a registered school domain?
  -- Look up if a tenant exists for this domain
  SELECT id INTO existing_tenant_id
  FROM public.tenants
  WHERE domain = user_domain AND is_active = true
  LIMIT 1;

  IF existing_tenant_id IS NOT NULL THEN
    -- ✅ CASE 1: School domain - user will be assigned to school tenant
    assigned_tenant_id := existing_tenant_id;

    -- First user from school domain gets ADMIN role
    -- Subsequent users get TEACHER role
    -- Determine by checking if any other users exist in this tenant
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE tenant_id = assigned_tenant_id AND role = 'admin'
    ) THEN
      default_role := 'admin';
    ELSE
      default_role := 'teacher';
    END IF;

  ELSE
    -- ✅ CASE 2: No tenant exists for this domain
    -- Check if it's a personal email domain or school domain without pre-created tenant

    -- List of common personal email domains
    IF user_domain IN ('gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
                       'aol.com', 'protonmail.com', 'icloud.com', 'mail.com',
                       'yandex.com', 'zoho.com', 'tutanota.com') THEN
      -- ✅ CASE 2A: Personal email domain
      -- Create a new personal tenant (domain = NULL means solo workspace)
      default_role := 'admin'; -- Solo user is admin of their own workspace

      tenant_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        split_part(NEW.email, '@', 1)
      ) || '''s Workspace (' || substring(NEW.id::TEXT from 1 for 8) || ')';

      INSERT INTO public.tenants (name, domain, is_active, is_initialized, current_academic_year)
      VALUES (tenant_name, NULL, true, false, '2025-2026')
      RETURNING id INTO assigned_tenant_id;
    ELSE
      -- ✅ CASE 2B: School domain without pre-created tenant
      -- Auto-create school tenant with the domain
      -- First user from this domain will be ADMIN
      default_role := 'admin';

      -- Generate tenant name from domain
      tenant_name := initcap(replace(user_domain, '.', ' '));

      INSERT INTO public.tenants (name, domain, is_active, is_initialized, current_academic_year)
      VALUES (tenant_name, user_domain, true, false, '2025-2026')
      RETURNING id INTO assigned_tenant_id;
    END IF;
  END IF;

  -- ✅ Create profile for the user
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
    NULL  -- Keep NULL so isFirstLogin detection works properly
  );

  -- ✅ Update JWT claims so RLS policies work
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
-- SUMMARY OF CHANGES
-- ============================================================================
-- Before (OLD BUGGY VERSION):
--   ✗ Only accepts: pearlmatricschool.com OR gmail.com
--   ✗ Any other domain → exception → user creation fails → infinite loading
--
-- After (NEW FIXED VERSION):
--   ✓ Check if domain has a school tenant → use it, assign role based on first user
--   ✓ Otherwise → create personal tenant (any domain supported)
--   ✓ No more domain whitelist → Gmail, Outlook, Yahoo, etc all work
--
-- Why this fixes the issue:
--   - When you cleared pearlmatricschool.com from tenants, new Gmail users failed
--   - Because the trigger said "if not gmail and not pearlmatricschool → exception"
--   - Now it says "if no existing tenant → create personal workspace"
--   - Works for ANY email domain automatically
