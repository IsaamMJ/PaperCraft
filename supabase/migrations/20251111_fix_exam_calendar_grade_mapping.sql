-- =====================================================
-- MIGRATION: Fix exam_calendar_grade_mapping table
-- =====================================================
-- Purpose: Replace grade_id with grade_section_id for proper mapping
-- Date: 2025-11-11
-- Reason: Exam calendars should map to grade sections (units that take exams),
--         not generic grades. Aligns with exam_timetable_entries structure.
-- =====================================================

-- Drop existing table and related objects
DROP TRIGGER IF EXISTS exam_calendar_grade_mapping_updated_at ON exam_calendar_grade_mapping;
DROP FUNCTION IF EXISTS update_exam_calendar_grade_mapping_updated_at();
DROP TABLE IF EXISTS exam_calendar_grade_mapping CASCADE;

-- Recreate the table with grade_section_id
CREATE TABLE IF NOT EXISTS exam_calendar_grade_mapping (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  exam_calendar_id UUID NOT NULL REFERENCES exam_calendar(id) ON DELETE CASCADE,
  grade_section_id UUID NOT NULL REFERENCES grade_sections(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),

  -- Ensure no duplicate grade section for same calendar
  UNIQUE(exam_calendar_id, grade_section_id)
);

-- ===== INDEXES =====
CREATE INDEX IF NOT EXISTS idx_exam_calendar_grade_mapping_tenant
ON exam_calendar_grade_mapping(tenant_id);

CREATE INDEX IF NOT EXISTS idx_exam_calendar_grade_mapping_calendar
ON exam_calendar_grade_mapping(exam_calendar_id);

CREATE INDEX IF NOT EXISTS idx_exam_calendar_grade_mapping_grade_section
ON exam_calendar_grade_mapping(grade_section_id);

CREATE INDEX IF NOT EXISTS idx_exam_calendar_grade_mapping_active
ON exam_calendar_grade_mapping(tenant_id, exam_calendar_id, is_active);

-- ===== TRIGGER FOR UPDATED_AT =====
CREATE OR REPLACE FUNCTION update_exam_calendar_grade_mapping_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER exam_calendar_grade_mapping_updated_at BEFORE UPDATE ON exam_calendar_grade_mapping
FOR EACH ROW EXECUTE FUNCTION update_exam_calendar_grade_mapping_updated_at();

-- ===== ROW LEVEL SECURITY =====
ALTER TABLE exam_calendar_grade_mapping ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "exam_calendar_grade_mapping_select_own_tenant" ON exam_calendar_grade_mapping;
CREATE POLICY "exam_calendar_grade_mapping_select_own_tenant" ON exam_calendar_grade_mapping FOR SELECT
USING (tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "exam_calendar_grade_mapping_insert_admin_only" ON exam_calendar_grade_mapping;
CREATE POLICY "exam_calendar_grade_mapping_insert_admin_only" ON exam_calendar_grade_mapping FOR INSERT
WITH CHECK (
  tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "exam_calendar_grade_mapping_update_admin_only" ON exam_calendar_grade_mapping;
CREATE POLICY "exam_calendar_grade_mapping_update_admin_only" ON exam_calendar_grade_mapping FOR UPDATE
USING (
  tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
  tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "exam_calendar_grade_mapping_delete_admin_only" ON exam_calendar_grade_mapping;
CREATE POLICY "exam_calendar_grade_mapping_delete_admin_only" ON exam_calendar_grade_mapping FOR DELETE
USING (
  tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
