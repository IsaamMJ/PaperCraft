-- =====================================================
-- EXAM TIMETABLE SYSTEM - CORE TABLES (SIMPLIFIED)
-- =====================================================

-- ===== 1. EXAM_CALENDAR TABLE =====
CREATE TABLE IF NOT EXISTS exam_calendar (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  exam_name TEXT NOT NULL,
  exam_type TEXT NOT NULL,
  month_number INTEGER NOT NULL,
  planned_start_date DATE NOT NULL,
  planned_end_date DATE NOT NULL,
  paper_submission_deadline DATE,
  display_order INTEGER NOT NULL DEFAULT 0,
  metadata JSONB,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT exam_calendar_date_range CHECK (planned_start_date <= planned_end_date),
  CONSTRAINT exam_calendar_tenant_unique UNIQUE(tenant_id, exam_name, exam_type, planned_start_date)
);

CREATE INDEX IF NOT EXISTS idx_exam_calendar_tenant ON exam_calendar(tenant_id);
CREATE INDEX IF NOT EXISTS idx_exam_calendar_active ON exam_calendar(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_exam_calendar_type ON exam_calendar(tenant_id, exam_type);


-- ===== 2. EXAM_TIMETABLES TABLE =====
CREATE TABLE IF NOT EXISTS exam_timetables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  exam_calendar_id UUID REFERENCES exam_calendar(id) ON DELETE SET NULL,
  exam_name TEXT NOT NULL,
  exam_type TEXT NOT NULL,
  exam_number INTEGER,
  academic_year TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  published_at TIMESTAMP WITH TIME ZONE,
  paper_submission_deadline TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  CONSTRAINT exam_timetables_status_check CHECK (status IN ('draft', 'published', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_exam_timetables_tenant ON exam_timetables(tenant_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_academic_year ON exam_timetables(tenant_id, academic_year);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_status ON exam_timetables(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_calendar ON exam_timetables(exam_calendar_id);
CREATE INDEX IF NOT EXISTS idx_exam_timetables_created_by ON exam_timetables(created_by);


-- ===== 3. EXAM_TIMETABLE_ENTRIES TABLE =====
CREATE TABLE IF NOT EXISTS exam_timetable_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  exam_timetable_id UUID NOT NULL REFERENCES exam_timetables(id) ON DELETE CASCADE,
  grade_id UUID NOT NULL REFERENCES grades(id) ON DELETE RESTRICT,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT,
  grade_section_id UUID REFERENCES grade_sections(id) ON DELETE RESTRICT,
  section TEXT NOT NULL,
  exam_date DATE NOT NULL,
  start_time TIME WITHOUT TIME ZONE NOT NULL,
  end_time TIME WITHOUT TIME ZONE NOT NULL,
  duration_minutes INTEGER NOT NULL,
  assigned_teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  assignment_status TEXT DEFAULT 'pending',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
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
ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS exam_timetable_entry_id UUID REFERENCES exam_timetable_entries(id) ON DELETE SET NULL;

ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS submission_status TEXT DEFAULT 'draft';

CREATE INDEX IF NOT EXISTS idx_question_papers_timetable_entry ON question_papers(exam_timetable_entry_id);
CREATE INDEX IF NOT EXISTS idx_question_papers_submission_status ON question_papers(submission_status);


-- ===== 5. CREATE TRIGGERS FOR UPDATED_AT =====
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS exam_calendar_updated_at ON exam_calendar;
CREATE TRIGGER exam_calendar_updated_at BEFORE UPDATE ON exam_calendar
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS exam_timetables_updated_at ON exam_timetables;
CREATE TRIGGER exam_timetables_updated_at BEFORE UPDATE ON exam_timetables
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS exam_timetable_entries_updated_at ON exam_timetable_entries;
CREATE TRIGGER exam_timetable_entries_updated_at BEFORE UPDATE ON exam_timetable_entries
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
