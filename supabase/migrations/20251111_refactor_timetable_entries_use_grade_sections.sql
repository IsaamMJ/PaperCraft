-- =====================================================
-- ADD SUBJECT VALIDATION INDEXES
-- =====================================================
-- This migration adds performance indexes to support subject validation
-- between exam_timetable_entries and grade_section_subject.

-- Step 1: Create index on exam_timetable_entries for subject lookup
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_subject_id
ON exam_timetable_entries(subject_id);

-- Step 2: Create index on exam_timetable_entries for grade/section lookup
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_grade_section
ON exam_timetable_entries(tenant_id, grade_id, section, subject_id);

-- Step 3: Create index on grade_section_subject for validation lookups
CREATE INDEX IF NOT EXISTS idx_grade_section_subject_offered
ON grade_section_subject(tenant_id, grade_id, section, subject_id)
WHERE is_offered = true;
