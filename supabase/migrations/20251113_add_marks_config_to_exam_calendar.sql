-- =====================================================
-- ADD MARKS CONFIGURATION TO EXAM CALENDARS
-- =====================================================
-- This migration adds support for configuring different marks
-- for different grade ranges within exam calendars.
--
-- marks_config is a JSONB column storing an array of configurations:
-- [
--   { "min_grade": 1, "max_grade": 5, "total_marks": 25, "label": "Primary" },
--   { "min_grade": 6, "max_grade": 8, "total_marks": 50, "label": "Secondary" },
--   { "min_grade": 9, "max_grade": 12, "total_marks": 80, "label": "Senior" }
-- ]

-- Add the marks_config column
ALTER TABLE exam_calendar
ADD COLUMN IF NOT EXISTS marks_config JSONB DEFAULT NULL;

-- Add index for efficient filtering/querying
CREATE INDEX IF NOT EXISTS idx_exam_calendar_marks_config
ON exam_calendar USING gin(marks_config);

-- Add comment for documentation
COMMENT ON COLUMN exam_calendar.marks_config IS
'JSONB array of mark configurations for different grade ranges.
Each configuration contains: min_grade, max_grade, total_marks, label';
