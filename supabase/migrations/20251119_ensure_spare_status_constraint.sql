-- Migration: Ensure spare status constraint exists
-- Date: 2025-11-19
-- Purpose: Make sure the CHECK constraint allows 'spare' status

-- Step 1: Drop the old status check constraint if it exists (without the spare status)
ALTER TABLE public.question_papers
DROP CONSTRAINT IF EXISTS question_papers_status_check;

-- Step 2: Add new constraint with 'spare' status included
ALTER TABLE public.question_papers
ADD CONSTRAINT question_papers_status_check CHECK (
  status = ANY (ARRAY['draft'::text, 'submitted'::text, 'approved'::text, 'rejected'::text, 'spare'::text])
);

-- Step 3: Document the valid statuses
COMMENT ON CONSTRAINT question_papers_status_check ON public.question_papers IS
'Valid paper statuses:
- draft: Local, unpublished
- submitted: Awaiting review
- approved: Selected for printing (only one per grade+subject+academic_year)
- rejected: Returned with feedback
- spare: Marked as backup/spare (auto-set when another paper approved for same grade+subject)';
