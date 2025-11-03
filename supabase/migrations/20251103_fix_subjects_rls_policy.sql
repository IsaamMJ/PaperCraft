-- Fix RLS policies for subjects table to allow admin insert/update
-- Migration: 20251103_fix_subjects_rls_policy
-- Uses JWT claims for role checking (set in raw_app_meta_data during profile creation)

-- Drop existing restrictive policies if any
DROP POLICY IF EXISTS "subjects_tenant_isolation" ON public.subjects;
DROP POLICY IF EXISTS "Users can view subjects" ON public.subjects;
DROP POLICY IF EXISTS "Authenticated users can view subjects" ON public.subjects;

-- Enable RLS if not already enabled
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read subjects for their tenant
CREATE POLICY "subjects_select_for_tenant"
  ON public.subjects FOR SELECT
  TO authenticated
  USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    OR (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to insert subjects
CREATE POLICY "subjects_insert_for_admin"
  ON public.subjects FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to update subjects
CREATE POLICY "subjects_update_for_admin"
  ON public.subjects FOR UPDATE
  TO authenticated
  USING (
    (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to delete subjects
CREATE POLICY "subjects_delete_for_admin"
  ON public.subjects FOR DELETE
  TO authenticated
  USING (
    (auth.jwt() ->> 'role') = 'admin'
  );
