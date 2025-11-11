-- =====================================================
-- REFACTOR EXAM_TIMETABLE_ENTRIES TO USE GRADE_SECTIONS
-- =====================================================
-- This migration refactors exam_timetable_entries to store grade_section_id
-- instead of separate grade_id + section columns.
--
-- Benefits:
-- - Referential integrity: ensure only valid section/grade combos
-- - Data consistency: section can't be invalid or out of sync
-- - Better queries: JOIN grade_sections to get both grade_id and section_name

-- Step 1: Add new grade_section_id column
ALTER TABLE exam_timetable_entries
ADD COLUMN grade_section_id UUID REFERENCES grade_sections(id) ON DELETE RESTRICT;

-- Step 2: Migrate data from existing grade_id + section combo to grade_section_id
-- This assumes grade_section exists with matching grade_id and section_name
UPDATE exam_timetable_entries ete
SET grade_section_id = gs.id
FROM grade_sections gs
WHERE ete.grade_id = gs.grade_id
  AND ete.section = gs.section_name
  AND gs.tenant_id = ete.tenant_id;

-- Step 3: Make grade_section_id NOT NULL (required field)
ALTER TABLE exam_timetable_entries
ALTER COLUMN grade_section_id SET NOT NULL;

-- Step 4: Drop the old columns (keep for now, can remove later if needed)
-- NOTE: Keeping grade_id and section for backward compatibility
-- In a future migration, we can remove these columns after confirming no code references them
-- ALTER TABLE exam_timetable_entries DROP COLUMN grade_id;
-- ALTER TABLE exam_timetable_entries DROP COLUMN section;

-- Step 5: Add index on new foreign key
CREATE INDEX IF NOT EXISTS idx_exam_timetable_entries_grade_section
ON exam_timetable_entries(grade_section_id);

-- Step 6: Update RLS policies if needed (policies should still work with tenant_id)
-- RLS policies remain unchanged as they're based on tenant_id
