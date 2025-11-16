-- Migration: Add auto-assignment support for question papers
-- Date: 2025-11-16
-- Purpose:
--   1. Add exam_timetable_entry_id column to link papers to exam entries
--   2. Modify paper_sections constraint to allow empty arrays for draft papers
--   3. This enables auto-assignment of papers when timetable is published

-- Step 1: Add exam_timetable_entry_id column to question_papers
ALTER TABLE public.question_papers
ADD COLUMN exam_timetable_entry_id uuid NULL;

-- Step 2: Add foreign key constraint for exam_timetable_entry_id
ALTER TABLE public.question_papers
ADD CONSTRAINT question_papers_exam_timetable_entry_id_fkey
FOREIGN KEY (exam_timetable_entry_id)
REFERENCES public.exam_timetable_entries (id)
ON DELETE SET NULL;

-- Step 3: Create index on exam_timetable_entry_id for query performance
CREATE INDEX IF NOT EXISTS idx_question_papers_exam_timetable_entry_id
ON public.question_papers USING btree (exam_timetable_entry_id);

-- Step 4: Create index to quickly find papers by teacher and timetable entry
CREATE INDEX IF NOT EXISTS idx_question_papers_user_exam_timetable
ON public.question_papers USING btree (user_id, exam_timetable_entry_id);

-- Step 5: Drop old paper_sections constraint that requires non-empty array
ALTER TABLE public.question_papers
DROP CONSTRAINT IF EXISTS question_papers_sections_valid;

-- Step 6: Add new constraint allowing empty arrays for draft papers
ALTER TABLE public.question_papers
ADD CONSTRAINT question_papers_sections_valid CHECK (
  (jsonb_typeof(paper_sections) = 'array'::text)
  AND (
    (jsonb_array_length(paper_sections) > 0)
    OR (status = 'draft'::text)
  )
);

-- Step 7: Create index for auto-assigned papers (where exam_timetable_entry_id is NOT NULL)
CREATE INDEX IF NOT EXISTS idx_question_papers_auto_assigned
ON public.question_papers USING btree (exam_timetable_entry_id, status, created_at DESC)
WHERE exam_timetable_entry_id IS NOT NULL;

-- Step 8: Document the change
COMMENT ON COLUMN public.question_papers.exam_timetable_entry_id IS
'Links to exam_timetable_entries for auto-assigned papers.
NULL indicates paper was created manually without auto-assignment.
Used to distinguish between auto-assigned papers (pre-filled metadata)
and manual papers (legacy, created before auto-assignment feature).';
