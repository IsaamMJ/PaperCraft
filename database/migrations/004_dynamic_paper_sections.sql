-- Migration 004: Dynamic Paper Sections - Replace Exam Types with Flexible Section Builder
-- This migration removes the rigid exam_types system and replaces it with dynamic sections
-- allowing teachers to create paper structures on-the-fly with auto-saved patterns

-- ============================================================================
-- STEP 1: Create teacher_patterns table
-- ============================================================================

CREATE TABLE IF NOT EXISTS teacher_patterns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,

  -- Pattern metadata
  name TEXT NOT NULL,

  -- Section structure stored as JSONB
  -- Format: [{"name": "Part A", "type": "multiple_choice", "questions": 10, "marks_per_question": 2}, ...]
  sections JSONB NOT NULL,

  -- Computed totals for quick filtering/sorting
  total_questions INT NOT NULL,
  total_marks INT NOT NULL,

  -- Usage tracking
  use_count INT DEFAULT 0,
  last_used_at TIMESTAMP WITH TIME ZONE,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT teacher_patterns_sections_valid
    CHECK (
      jsonb_typeof(sections) = 'array'
      AND jsonb_array_length(sections) > 0
    ),
  CONSTRAINT teacher_patterns_questions_positive
    CHECK (total_questions > 0),
  CONSTRAINT teacher_patterns_marks_positive
    CHECK (total_marks > 0)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS teacher_patterns_teacher_subject_idx
  ON teacher_patterns (teacher_id, subject_id, last_used_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS teacher_patterns_tenant_idx
  ON teacher_patterns (tenant_id);

-- Row Level Security
ALTER TABLE teacher_patterns ENABLE ROW LEVEL SECURITY;

-- Teachers can see and manage their own patterns
CREATE POLICY "Teachers manage own patterns"
  ON teacher_patterns
  FOR ALL
  USING (teacher_id = auth.uid());

-- Note: If you have a users table with tenant_id, you can add admin access:
-- CREATE POLICY "Admins see all tenant patterns"
--   ON teacher_patterns
--   FOR SELECT
--   USING (
--     tenant_id IN (
--       SELECT tenant_id FROM users WHERE id = auth.uid() AND role = 'admin'
--     )
--   );

-- ============================================================================
-- STEP 2: Modify question_papers table
-- ============================================================================

-- Drop dependent views first
DROP VIEW IF EXISTS question_papers_enriched CASCADE;

-- Add new column for dynamic sections
ALTER TABLE question_papers
  ADD COLUMN IF NOT EXISTS paper_sections JSONB;

-- Migrate existing data from exam_types to paper_sections
-- This pulls the sections from the exam_type and stores them directly in the paper
UPDATE question_papers qp
SET paper_sections = et.sections
FROM exam_types et
WHERE qp.exam_type_id = et.id
  AND qp.paper_sections IS NULL;

-- Make paper_sections required (now that data is migrated)
ALTER TABLE question_papers
  ALTER COLUMN paper_sections SET NOT NULL;

-- Add constraint to validate sections structure
ALTER TABLE question_papers
  ADD CONSTRAINT question_papers_sections_valid
    CHECK (
      jsonb_typeof(paper_sections) = 'array'
      AND jsonb_array_length(paper_sections) > 0
    );

-- Drop the index on exam_type_id
DROP INDEX IF EXISTS idx_question_papers_exam_type_id CASCADE;

-- Drop the exam_type_id foreign key constraint and column
ALTER TABLE question_papers
  DROP CONSTRAINT IF EXISTS question_papers_exam_type_id_fkey CASCADE;

ALTER TABLE question_papers
  DROP COLUMN IF EXISTS exam_type_id CASCADE;

-- ============================================================================
-- STEP 3: Drop exam_types table (no longer needed)
-- ============================================================================

DROP TABLE IF EXISTS exam_types CASCADE;

-- ============================================================================
-- STEP 4: Update functions and triggers
-- ============================================================================

-- Update the updated_at trigger for teacher_patterns
CREATE OR REPLACE FUNCTION update_teacher_patterns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER teacher_patterns_updated_at_trigger
  BEFORE UPDATE ON teacher_patterns
  FOR EACH ROW
  EXECUTE FUNCTION update_teacher_patterns_updated_at();

-- ============================================================================
-- VERIFICATION QUERIES (Run these to verify migration success)
-- ============================================================================

-- Check teacher_patterns table exists with correct structure
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'teacher_patterns'
-- ORDER BY ordinal_position;

-- Check question_papers has paper_sections and no exam_type_id
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'question_papers'
-- AND column_name IN ('paper_sections', 'exam_type_id');

-- Check exam_types table is dropped
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_name = 'exam_types';

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================

-- NOTE: Rollback is complex because we deleted exam_types table
-- Only use this if you have a backup of the exam_types data

-- To rollback:
-- 1. Restore exam_types table from backup
-- 2. ALTER TABLE question_papers ADD COLUMN exam_type_id UUID REFERENCES exam_types(id);
-- 3. UPDATE question_papers SET exam_type_id = (select appropriate exam_type based on paper data)
-- 4. ALTER TABLE question_papers DROP COLUMN paper_sections;
-- 5. DROP TABLE teacher_patterns CASCADE;
