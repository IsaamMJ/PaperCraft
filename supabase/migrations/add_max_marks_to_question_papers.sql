-- Add max_marks column to question_papers table
-- This stores the maximum marks for an exam paper from the timetable entry

ALTER TABLE public.question_papers
ADD COLUMN IF NOT EXISTS max_marks integer NULL;

-- Create an index on max_marks for faster queries
CREATE INDEX IF NOT EXISTS idx_question_papers_max_marks
ON public.question_papers(max_marks);

-- Add a check constraint to ensure max_marks is positive if set
ALTER TABLE public.question_papers
ADD CONSTRAINT question_papers_max_marks_check
CHECK (max_marks IS NULL OR max_marks > 0);

COMMENT ON COLUMN public.question_papers.max_marks
IS 'Maximum marks for this exam paper, derived from the timetable entry. Can be NULL if not set.';
