-- Fix RLS infinite recursion issue for profiles table
-- This migration creates a SECURITY DEFINER helper function to prevent
-- infinite recursion when RLS policies query the same table they're protecting

-- ============================================================================
-- CREATE: Helper function to get user's tenant_id (bypasses RLS)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_tenant_id(user_id UUID)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT tenant_id FROM public.profiles WHERE id = user_id LIMIT 1;
$$;

-- ============================================================================
-- UPDATE: profiles_select_consolidated policy to use helper function
-- ============================================================================

-- Drop the old policy that caused infinite recursion
DROP POLICY IF EXISTS "profiles_select_consolidated" ON profiles;

-- Create new policy using the SECURITY DEFINER helper function
CREATE POLICY "profiles_select_consolidated" ON profiles
  FOR SELECT
  USING (
    -- Users can view their own profile
    auth.uid() = id
    OR
    -- Users can view profiles in their tenant
    -- Using helper function prevents infinite recursion
    (
      tenant_id IS NOT NULL
      AND tenant_id = public.get_user_tenant_id(auth.uid())
    )
  );

-- ============================================================================
-- EXPLANATION
-- ============================================================================
--
-- Problem: The original RLS policy tried to query profiles table to check
-- tenant_id, which triggered the same policy again, causing infinite recursion.
--
-- Solution: Created a SECURITY DEFINER function that bypasses RLS when
-- fetching the current user's tenant_id. This breaks the recursion cycle.
--
-- The SECURITY DEFINER function runs with elevated privileges and skips RLS,
-- so it can safely query the profiles table without triggering the policy.
--
-- ============================================================================
-- WHAT THIS FIXES
-- ============================================================================
--
-- ✅ Admin Dashboard - Shows actual teacher names (not "User")
-- ✅ Teacher Assignment - Shows all teachers from same tenant
-- ✅ Manage Users - Shows all users from same tenant
-- ✅ No more "infinite recursion detected in policy" errors
-- ✅ Login continues to work normally
--
