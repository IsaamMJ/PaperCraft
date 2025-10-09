-- Fix RLS policies for grades table to allow admin insert/update
-- Migration: fix_grades_rls_policy

-- Drop existing restrictive policies if any
DROP POLICY IF EXISTS "Users can view grades" ON grades;
DROP POLICY IF EXISTS "Admins can manage grades" ON grades;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON grades;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON grades;

-- Allow all authenticated users to read grades
CREATE POLICY "Authenticated users can view grades"
  ON grades FOR SELECT
  TO authenticated
  USING (true);

-- Allow admins to insert grades
CREATE POLICY "Admins can insert grades"
  ON grades FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
      AND role = 'admin'
    )
  );

-- Allow admins to update grades
CREATE POLICY "Admins can update grades"
  ON grades FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
      AND role = 'admin'
    )
  );

-- Allow admins to delete grades
CREATE POLICY "Admins can delete grades"
  ON grades FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
      AND role = 'admin'
    )
  );
