-- Run this in Supabase SQL Editor to diagnose the issue

-- 1. Check if grade_section_id exists in exam_timetable_entries
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'exam_timetable_entries'
ORDER BY ordinal_position;

-- 2. Check the structure of grade_section_subject table
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'grade_section_subject'
ORDER BY ordinal_position;

-- 3. Check primary keys and unique constraints on grade_section_subject
SELECT
  constraint_name,
  constraint_type,
  table_name
FROM information_schema.table_constraints
WHERE table_name = 'grade_section_subject';

-- 4. Check all constraints on exam_timetable_entries
SELECT
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'exam_timetable_entries'
ORDER BY constraint_name;
