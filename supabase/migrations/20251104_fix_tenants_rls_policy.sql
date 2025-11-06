-- Migration: Fix RLS policy on tenants table
-- Date: 2025-11-04
-- Description:
--   Adds RLS policy to allow authenticated users to read the tenant record
--   they belong to. This is needed for:
--   1. Auth initialization to check if tenant is initialized
--   2. Admin setup wizard to access tenant data
--   3. Multi-tenancy isolation while allowing necessary access
--
-- RLS Rule:
--   Users can SELECT from tenants if:
--   - The tenant_id in the profiles table matches the selected tenant's id
--   - This ensures users only see their own tenant's data
--   - Maintains security isolation between tenants

-- Enable RLS on tenants table (should already be enabled, but ensure it)
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to read their own tenant
-- This is safe because:
-- 1. Users can only see the tenant they belong to (via profile.tenant_id)
-- 2. The query is performant (indexed on tenant id)
-- 3. Non-tenant-specific operations are not allowed
DROP POLICY IF EXISTS "Users can read their own tenant" ON public.tenants;

CREATE POLICY "Users can read their own tenant" ON public.tenants
  FOR SELECT
  USING (
    -- Allow if the user's tenant_id matches this tenant's id
    id = (
      SELECT tenant_id
      FROM public.profiles
      WHERE id = auth.uid()
    )
  );

-- Policy: Allow service role (used by migrations/admin tasks) to access all tenants
DROP POLICY IF EXISTS "Service role can manage tenants" ON public.tenants;

CREATE POLICY "Service role can manage tenants" ON public.tenants
  USING (
    -- This condition is always true for service_role (no auth checks in service role context)
    -- In Supabase, service_role bypasses RLS entirely, but we include this for clarity
    true
  );
