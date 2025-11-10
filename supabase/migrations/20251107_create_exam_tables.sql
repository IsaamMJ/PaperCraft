-- =====================================================
-- EXAM TIMETABLE SYSTEM - CORE TABLES
-- =====================================================
-- This migration creates the exam calendar and timetable structure
-- for managing exam schedules and paper submissions.
-- =====================================================

-- ===== 1. EXAM_CALENDAR TABLE =====
-- Represents an exam period/term (e.g., "Mid-term Exams Nov 2025")
-- This is a template/master record that can be reused
CREATE TABLE IF NOT EXISTS exam_calendar (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  exam_name TEXT NOT NULL, -- e.g., "Mid-term Exams", "Final Exams"
  exam_type TEXT NOT NULL, -- e.g., "mid_term", "final", "unit_test", "monthly"
  month_number INTEGER NOT NULL, -- 1-12, for quick filtering
  planned_start_date DATE NOT NULL,
  planned_end_date DATE NOT NULL,
  paper_submission_deadline DATE, -- Optional: when papers must be submitted
  display_order INTEGER NOT NULL DEFAULT 0,
  metadata JSONB, -- For future extensibility (e.g., additional notes)
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

  -- Constraints
  CONSTRAINT exam_calendar_date_range CHECK (planned_start_date <= planned_end_date),
  CONSTRAINT exam_calendar_tenant_unique UNIQUE(tenant_id, exam_name, exam_type, planned_start_date)
);

CREATE INDEX IF NOT EXISTS idx_exam_calendar_tenant ON exam_calendar(tenant_id);
CREATE INDEX IF NOT EXISTS idx_exam_calendar_active ON exam_calendar(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_exam_calendar_type ON exam_calendar(tenant_id, exam_type);


-- ===== 2. EXAM_TIMETABLES TABLE =====
-- Represents an actual instance of an exam timetable for an academic year
-- Can reference a calendar or be standalone
CREATE TABLE IF NOT EXISTS exam_timetables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  exam_calendar_id UUID REFERENCES exam_calendar(id) ON DELETE SET NULL,
  exam_name TEXT NOT NULL, -- Can be same or different from calendar
  exam_type TEXT NOT NULL, -- mid_term, final, unit_test, etc.
  exam_number INTEGER, -- 1st, 2nd, 3rd attempt/iteration
  academic_year TEXT NOT NULL, -- e.g., "2025-2026"
  status TEXT NOT NULL DEFAULT 'draft', -- draft, published, archived
  published_at TIMESTAMP WITH TIME ZONE,
  paper_submission_deadline TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB, -- Additional metadata like notes, version info
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

  -- Constraints
  CONSTRAINT exam_timetables_status_check CHECK (status IN ('draft', 'published', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_exam_timetables_tenant ON exam_timetables(tenant_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_academic_year ON exam_timetables(tenant_id, academic_year);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_status ON exam_timetables(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_calendar ON exam_timetables(exam_calendar_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_created_by ON exam_timetables(created_by);


-- ===== 3. EXAM_TIMETABLE_ENTRIES TABLE =====
-- Represents individual exam entries (one per subject per grade per exam)
-- Links a grade+subject+date to a timetable
CREATE TABLE IF NOT EXISTS exam_timetable_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  exam_timetable_id UUID NOT NULL REFERENCES exam_timetables(id) ON DELETE CASCADE,
  grade_id UUID NOT NULL REFERENCES grades(id) ON DELETE RESTRICT,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  grade_section_id UUID REFERENCES grade_sections(id) ON DELETE RESTRICT,
  section TEXT NOT NULL, -- A, B, C, etc. (stored both as FK and text for convenience)
  exam_date DATE NOT NULL,
  start_time TIME WITHOUT TIME ZONE NOT NULL,
  end_time TIME WITHOUT TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL,
  assigned_teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assignment_status TEXT DEFAULT 'pending', -- pending, acknowledged, in_progress
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

  -- Constraints
  CONSTRAINT exam_entry_time_range CHECK (start_time < end_time),
  CONSTRAINT exam_entry_duration_calc CHECK (
    EXTRACT(EPOCH FROM (end_time - start_time))/60 = duration_minutes
  ),
  CONSTRAINT exam_entry_unique_grade_subject_date UNIQUE(
    exam_timetable_id, grade_id, subject_id, section, exam_date
  ),
  CONSTRAINT exam_entry_assignment_status_check CHECK (
    assignment_status IN ('pending', 'acknowledged', 'in_progress')
  )
);

CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_timetable ON exam_timetable_entries(exam_timetable_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_grade_subject ON exam_timetable_entries(grade_id, subject_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_date ON exam_timetable_entries(exam_date);
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_teacher ON exam_timetable_entries(assigned_teacher_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_active ON exam_timetable_entries(tenant_id, is_active);


-- ===== 4. ALTER QUESTION_PAPERS TABLE =====
-- Add link to exam timetable entry for tracking which paper belongs to which exam
ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS exam_timetable_entry_id UUID REFERENCES exam_timetable_entries(id) ON DELETE SET NULL;

-- Add submission status for better workflow tracking
ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS submission_status TEXT DEFAULT 'draft';

CREATE INDEX IF NOT EXISTS idx_question_papers_timetable_entry ON question_papers(exam_timetable_entry_id);
CREATE INDEX IF NOT EXISTS idx_question_papers_submission_status ON question_papers(submission_status);


-- ===== 5. CREATE TRIGGERS FOR UPDATED_AT =====
-- Auto-update the updated_at timestamp on every change

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate triggers to ensure idempotency
DROP TRIGGER IF EXISTS exam_calendar_updated_at ON exam_calendar;
CREATE TRIGGER exam_calendar_updated_at BEFORE UPDATE ON exam_calendar
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS exam_timetables_updated_at ON exam_timetables;
CREATE TRIGGER exam_timetables_updated_at BEFORE UPDATE ON exam_timetables
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS exam_timetable_entries_updated_at ON exam_timetable_entries;
CREATE TRIGGER exam_timetable_entries_updated_at BEFORE UPDATE ON exam_timetable_entries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ===== 6. CREATE COMMENTS FOR DOCUMENTATION =====
COMMENT ON TABLE exam_calendar IS 'Master template for exam periods. Can be reused across years.';
COMMENT ON TABLE exam_timetables IS 'Actual exam timetable instance for a specific academic year.';
COMMENT ON TABLE exam_timetable_entries IS 'Individual exam entry: a specific grade+subject exam on a specific date/time.';

COMMENT ON COLUMN exam_timetable_entries.assignment_status IS 'Tracks whether teacher has been assigned and acknowledged the exam entry.';
COMMENT ON COLUMN exam_timetable_entries.section IS 'Section (A, B, C) - stored redundantly with grade_section_id for easier querying.';
