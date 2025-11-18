-- Update profiles role check constraint to include new reviewer roles
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (
  role = ANY (
    ARRAY[
      'admin'::text,
      'director'::text,
      'teacher'::text,
      'office_staff'::text,
      'primary_reviewer'::text,
      'secondary_reviewer'::text,
      'student'::text,
      'user'::text,
      'blocked'::text
    ]
  )
);

-- Create reviewer_grade_assignments table
CREATE TABLE IF NOT EXISTS public.reviewer_grade_assignments (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  grade_min integer NOT NULL CHECK (grade_min >= 1 AND grade_min <= 12),
  grade_max integer NOT NULL CHECK (grade_max >= 1 AND grade_max <= 12 AND grade_max >= grade_min),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT unique_reviewer_per_tenant UNIQUE(tenant_id, reviewer_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_reviewer_assignments_tenant_id
  ON public.reviewer_grade_assignments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_reviewer_assignments_reviewer_id
  ON public.reviewer_grade_assignments(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_reviewer_assignments_grade_range
  ON public.reviewer_grade_assignments(grade_min, grade_max);

-- Enable RLS
ALTER TABLE public.reviewer_grade_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "reviewer_assignments_select_policy" ON public.reviewer_grade_assignments;
DROP POLICY IF EXISTS "reviewer_assignments_insert_policy" ON public.reviewer_grade_assignments;
DROP POLICY IF EXISTS "reviewer_assignments_update_policy" ON public.reviewer_grade_assignments;
DROP POLICY IF EXISTS "reviewer_assignments_delete_policy" ON public.reviewer_grade_assignments;

-- Select: Admins can view all, users can view their own
CREATE POLICY "reviewer_assignments_select_policy" ON public.reviewer_grade_assignments
  FOR SELECT
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    OR
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Insert: Only admins can create
CREATE POLICY "reviewer_assignments_insert_policy" ON public.reviewer_grade_assignments
  FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Update: Only admins can update
CREATE POLICY "reviewer_assignments_update_policy" ON public.reviewer_grade_assignments
  FOR UPDATE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Delete: Only admins can delete
CREATE POLICY "reviewer_assignments_delete_policy" ON public.reviewer_grade_assignments
  FOR DELETE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );
