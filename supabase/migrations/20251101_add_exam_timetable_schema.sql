-- ============================================================================
-- EXAM TIMETABLE SYSTEM MIGRATION
-- ============================================================================
-- This migration adds the complete exam timetable system to support:
-- 1. Grade sections (multiple sections per grade)
-- 2. Teacher subject assignments with sections
-- 3. Exam calendar planning
-- 4. Exam timetable creation and management
-- 5. RLS policies for multi-tenant security
--
-- Date: 2025-11-01
-- ============================================================================

-- ============================================================================
-- STEP 1: MODIFY EXISTING TABLES
-- ============================================================================

-- 1.1 Modify question_papers table: Add section field
-- First, add the section column
ALTER TABLE public.question_papers
ADD COLUMN IF NOT EXISTS section text null;

-- Add a default comment to section field
COMMENT ON COLUMN public.question_papers.section IS 'The class section (e.g., A, B, C) for which this paper is intended. Can be null for backward compatibility.';

-- 1.2 Update question_papers unique constraint to include section
-- Note: We need to drop the old constraint and create a new one
-- Since this requires careful handling, we'll create a new unique index instead
-- The new constraint should consider section as part of uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_question_papers_unique_with_section
ON public.question_papers(tenant_id, subject_id, grade_id, academic_year, title, COALESCE(section, ''))
WHERE status != 'draft'::text;

-- 1.3 Modify notifications table: Update type constraint to include new types
-- Drop existing constraint and recreate with new types
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check CHECK (
  type = ANY (array[
    'paper_approved'::text,
    'paper_rejected'::text,
    'paper_resubmitted'::text,
    'paper_created'::text,
    'paper_submission_deadline'::text,
    'paper_pending_review'::text,
    'timetable_published'::text
  ])
);

-- ============================================================================
-- STEP 2: CREATE NEW TABLES FOR EXAM TIMETABLE SYSTEM
-- ============================================================================

-- 2.1 Create grade_sections table
-- Stores the sections (A, B, C, etc.) for each grade in each tenant
CREATE TABLE IF NOT EXISTS public.grade_sections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  grade_id uuid NOT NULL,
  section_name text NOT NULL,
  display_order integer NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT grade_sections_pkey PRIMARY KEY (id),
  CONSTRAINT grade_sections_tenant_grade_section_unique UNIQUE (tenant_id, grade_id, section_name),
  CONSTRAINT grade_sections_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT grade_sections_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES grades (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for grade_sections
CREATE INDEX IF NOT EXISTS idx_grade_sections_tenant_id
ON public.grade_sections USING btree (tenant_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_grade_sections_grade_id
ON public.grade_sections USING btree (grade_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_grade_sections_tenant_grade_active
ON public.grade_sections USING btree (tenant_id, grade_id, is_active) TABLESPACE pg_default;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_grade_sections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_grade_sections_updated_at
BEFORE UPDATE ON public.grade_sections
FOR EACH ROW
EXECUTE FUNCTION update_grade_sections_updated_at();

-- 2.2 Create teacher_subjects table
-- Stores the exact (grade, subject, section) tuples that each teacher teaches
-- This replaces the cartesian product issue from grade + subject selections
CREATE TABLE IF NOT EXISTS public.teacher_subjects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  grade_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  section text NOT NULL,
  academic_year text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT teacher_subjects_pkey PRIMARY KEY (id),
  CONSTRAINT teacher_subjects_unique UNIQUE (tenant_id, teacher_id, grade_id, subject_id, section, academic_year),
  CONSTRAINT teacher_subjects_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT teacher_subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES profiles (id) ON DELETE CASCADE,
  CONSTRAINT teacher_subjects_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES grades (id) ON DELETE CASCADE,
  CONSTRAINT teacher_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for teacher_subjects
CREATE INDEX IF NOT EXISTS idx_teacher_subjects_tenant_id
ON public.teacher_subjects USING btree (tenant_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_teacher_subjects_teacher_id
ON public.teacher_subjects USING btree (teacher_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_teacher_subjects_grade_subject
ON public.teacher_subjects USING btree (grade_id, subject_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_teacher_subjects_teacher_active
ON public.teacher_subjects USING btree (teacher_id, is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_teacher_subjects_academic_year
ON public.teacher_subjects USING btree (academic_year) TABLESPACE pg_default;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_teacher_subjects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_teacher_subjects_updated_at
BEFORE UPDATE ON public.teacher_subjects
FOR EACH ROW
EXECUTE FUNCTION update_teacher_subjects_updated_at();

-- 2.3 Create exam_calendar table
-- Planned exams for the school (e.g., June Monthly, September Quarterly, etc.)
CREATE TABLE IF NOT EXISTS public.exam_calendar (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  exam_name text NOT NULL,
  exam_type text NOT NULL DEFAULT 'monthlyTest',
  month_number integer NOT NULL,
  planned_start_date date NOT NULL,
  planned_end_date date NOT NULL,
  paper_submission_deadline date NULL,
  display_order integer NOT NULL DEFAULT 1,
  metadata jsonb NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT exam_calendar_pkey PRIMARY KEY (id),
  CONSTRAINT exam_calendar_tenant_name_unique UNIQUE (tenant_id, exam_name),
  CONSTRAINT exam_calendar_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT exam_calendar_month_check CHECK (month_number >= 1 AND month_number <= 12),
  CONSTRAINT exam_calendar_dates_check CHECK (planned_start_date <= planned_end_date)
) TABLESPACE pg_default;

-- Create indexes for exam_calendar
CREATE INDEX IF NOT EXISTS idx_exam_calendar_tenant_id
ON public.exam_calendar USING btree (tenant_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_calendar_month_number
ON public.exam_calendar USING btree (month_number) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_calendar_exam_type
ON public.exam_calendar USING btree (exam_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_calendar_tenant_active
ON public.exam_calendar USING btree (tenant_id, is_active) TABLESPACE pg_default;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_exam_calendar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_exam_calendar_updated_at
BEFORE UPDATE ON public.exam_calendar
FOR EACH ROW
EXECUTE FUNCTION update_exam_calendar_updated_at();

-- 2.4 Create exam_timetables table
-- The actual exam timetable created by admin (can be from calendar or ad-hoc)
CREATE TABLE IF NOT EXISTS public.exam_timetables (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  created_by uuid NOT NULL,
  exam_calendar_id uuid NULL,
  exam_name text NOT NULL,
  exam_type text NOT NULL DEFAULT 'monthlyTest',
  exam_number integer NULL,
  academic_year text NOT NULL,
  status text NOT NULL DEFAULT 'draft',
  published_at timestamp with time zone NULL,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT exam_timetables_pkey PRIMARY KEY (id),
  CONSTRAINT exam_timetables_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT exam_timetables_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles (id) ON DELETE RESTRICT,
  CONSTRAINT exam_timetables_exam_calendar_id_fkey FOREIGN KEY (exam_calendar_id) REFERENCES exam_calendar (id) ON DELETE SET NULL,
  CONSTRAINT exam_timetables_status_check CHECK (status IN ('draft', 'published', 'completed', 'cancelled')),
  CONSTRAINT exam_timetables_exam_type_check CHECK (exam_type IN ('monthlyTest', 'halfYearlyTest', 'quarterlyTest', 'finalExam', 'dailyTest'))
) TABLESPACE pg_default;

-- Create indexes for exam_timetables
CREATE INDEX IF NOT EXISTS idx_exam_timetables_tenant_id
ON public.exam_timetables USING btree (tenant_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetables_created_by
ON public.exam_timetables USING btree (created_by) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetables_status
ON public.exam_timetables USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetables_exam_calendar_id
ON public.exam_timetables USING btree (exam_calendar_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetables_tenant_status_published
ON public.exam_timetables USING btree (tenant_id, status, published_at DESC NULLS LAST) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetables_academic_year
ON public.exam_timetables USING btree (academic_year) TABLESPACE pg_default;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_exam_timetables_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_exam_timetables_updated_at
BEFORE UPDATE ON public.exam_timetables
FOR EACH ROW
EXECUTE FUNCTION update_exam_timetables_updated_at();

-- 2.5 Create exam_timetable_entries table
-- Individual entries in a timetable (one per grade/subject/section combination)
CREATE TABLE IF NOT EXISTS public.exam_timetable_entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  timetable_id uuid NOT NULL,
  grade_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  section text NOT NULL,
  exam_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  duration_minutes integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  CONSTRAINT exam_timetable_entries_pkey PRIMARY KEY (id),
  CONSTRAINT exam_timetable_entries_unique UNIQUE (timetable_id, grade_id, subject_id, section),
  CONSTRAINT exam_timetable_entries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT exam_timetable_entries_timetable_id_fkey FOREIGN KEY (timetable_id) REFERENCES exam_timetables (id) ON DELETE CASCADE,
  CONSTRAINT exam_timetable_entries_grade_id_fkey FOREIGN KEY (grade_id) REFERENCES grades (id) ON DELETE CASCADE,
  CONSTRAINT exam_timetable_entries_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
  CONSTRAINT exam_timetable_entries_time_check CHECK (start_time < end_time),
  CONSTRAINT exam_timetable_entries_duration_check CHECK (duration_minutes > 0)
) TABLESPACE pg_default;

-- Create indexes for exam_timetable_entries
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_tenant_id
ON public.exam_timetable_entries USING btree (tenant_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_timetable_id
ON public.exam_timetable_entries USING btree (timetable_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_grade_subject
ON public.exam_timetable_entries USING btree (grade_id, subject_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_exam_date
ON public.exam_timetable_entries USING btree (exam_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_timetable_grade_subject
ON public.exam_timetable_entries USING btree (timetable_id, grade_id, subject_id) TABLESPACE pg_default;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_exam_timetable_entries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_exam_timetable_entries_updated_at
BEFORE UPDATE ON public.exam_timetable_entries
FOR EACH ROW
EXECUTE FUNCTION update_exam_timetable_entries_updated_at();

-- ============================================================================
-- STEP 3: CREATE RLS POLICIES
-- ============================================================================
-- Note: These RLS policies assume that the auth schema and jwt claims are properly configured.
-- All tables should have RLS enabled to prevent cross-tenant data leakage.

-- Enable RLS on all new tables
ALTER TABLE public.grade_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_timetable_entries ENABLE ROW LEVEL SECURITY;

-- 3.1 RLS for grade_sections
CREATE POLICY grade_sections_tenant_isolation ON public.grade_sections
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');

-- 3.2 RLS for teacher_subjects
CREATE POLICY teacher_subjects_tenant_isolation ON public.teacher_subjects
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');

-- 3.3 RLS for exam_calendar
CREATE POLICY exam_calendar_tenant_isolation ON public.exam_calendar
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');

-- 3.4 RLS for exam_timetables
CREATE POLICY exam_timetables_tenant_isolation ON public.exam_timetables
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');

-- 3.5 RLS for exam_timetable_entries
CREATE POLICY exam_timetable_entries_tenant_isolation ON public.exam_timetable_entries
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid OR auth.jwt() ->> 'role'::text = 'admin');

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- This migration has created:
-- 1. grade_sections - for managing sections per grade
-- 2. teacher_subjects - for exact (grade, subject, section) assignments
-- 3. exam_calendar - for planned exams
-- 4. exam_timetables - for actual timetables
-- 5. exam_timetable_entries - for individual timetable entries
--
-- Modified tables:
-- 1. question_papers - added section field and unique index
-- 2. notifications - added new notification types
--
-- All new tables have RLS enabled for multi-tenant security.
-- ============================================================================
