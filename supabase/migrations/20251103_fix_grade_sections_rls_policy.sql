-- Fix RLS policies for grade_sections table to allow admin insert/update
-- Migration: 20251103_fix_grade_sections_rls_policy
-- Uses JWT claims for role checking (set in raw_app_meta_data during profile creation)

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "grade_sections_tenant_isolation" ON public.grade_sections;

-- Create separate policies for each operation

-- Allow authenticated users to read grade_sections for their tenant
CREATE POLICY "grade_sections_select_for_tenant"
  ON public.grade_sections FOR SELECT
  TO authenticated
  USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    OR (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to insert grade_sections
CREATE POLICY "grade_sections_insert_for_admin"
  ON public.grade_sections FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to update grade_sections
CREATE POLICY "grade_sections_update_for_admin"
  ON public.grade_sections FOR UPDATE
  TO authenticated
  USING (
    (auth.jwt() ->> 'role') = 'admin'
  );

-- Allow authenticated admins to delete grade_sections
CREATE POLICY "grade_sections_delete_for_admin"
  ON public.grade_sections FOR DELETE
  TO authenticated
  USING (
    (auth.jwt() ->> 'role') = 'admin'
  );
