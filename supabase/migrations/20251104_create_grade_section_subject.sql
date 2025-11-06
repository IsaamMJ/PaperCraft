-- Create grade_section_subject table for managing which subjects are offered in specific grade+section combinations
-- This allows per-tenant, per-grade, per-section control over subject availability

CREATE TABLE IF NOT EXISTS public.grade_section_subject (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  grade_id uuid NOT NULL,
  section text NOT NULL,
  subject_id uuid NOT NULL,
  is_offered boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT grade_section_subject_pkey PRIMARY KEY (id),
  CONSTRAINT grade_section_subject_tenant_id_grade_id_section_subject_id_key
    UNIQUE (tenant_id, grade_id, section, subject_id),
  CONSTRAINT grade_section_subject_grade_id_fkey
    FOREIGN KEY (grade_id) REFERENCES grades (id),
  CONSTRAINT grade_section_subject_subject_id_fkey
    FOREIGN KEY (subject_id) REFERENCES subjects (id),
  CONSTRAINT grade_section_subject_tenant_id_fkey
    FOREIGN KEY (tenant_id) REFERENCES tenants (id),
  CONSTRAINT grade_section_subject_tenant_id_grade_id_section_fkey
    FOREIGN KEY (tenant_id, grade_id, section) REFERENCES grade_sections (tenant_id, grade_id, section_name)
);

-- Create trigger for updated_at column
CREATE TRIGGER set_grade_section_subject_updated_at BEFORE UPDATE ON grade_section_subject
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes for common queries
CREATE INDEX idx_grade_section_subject_tenant_grade_section
  ON public.grade_section_subject(tenant_id, grade_id, section);
CREATE INDEX idx_grade_section_subject_tenant_subject
  ON public.grade_section_subject(tenant_id, subject_id);
CREATE INDEX idx_grade_section_subject_is_offered
  ON public.grade_section_subject(is_offered);

-- Enable RLS
ALTER TABLE public.grade_section_subject ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Users can see subject assignments for their tenant
CREATE POLICY "Allow users to see grade section subjects for their tenant"
  ON public.grade_section_subject
  FOR SELECT
  TO authenticated
  USING (tenant_id = auth.jwt() ->> 'tenant_id');

-- Create RLS policy: Admins can manage grade section subjects
CREATE POLICY "Allow admins to manage grade section subjects"
  ON public.grade_section_subject
  FOR ALL
  TO authenticated
  USING (
    tenant_id = auth.jwt() ->> 'tenant_id'
    AND (
      SELECT role FROM public.profiles
      WHERE id = auth.uid() AND tenant_id = auth.jwt() ->> 'tenant_id'
    ) = 'admin'
  );

-- Add table comments
COMMENT ON TABLE public.grade_section_subject IS
  'Mapping of subjects to grade+section combinations, allowing per-section subject configuration';
COMMENT ON COLUMN public.grade_section_subject.id IS 'Unique identifier';
COMMENT ON COLUMN public.grade_section_subject.tenant_id IS 'Tenant this assignment belongs to';
COMMENT ON COLUMN public.grade_section_subject.grade_id IS 'Grade this assignment is for';
COMMENT ON COLUMN public.grade_section_subject.section IS 'Section name';
COMMENT ON COLUMN public.grade_section_subject.subject_id IS 'Subject being offered';
COMMENT ON COLUMN public.grade_section_subject.is_offered IS 'Whether this subject is currently offered';
COMMENT ON COLUMN public.grade_section_subject.display_order IS 'Display order for UI rendering';
