-- Migration: Add 'spare' status for duplicate paper selection
-- Date: 2025-11-18
-- Purpose:
--   1. Add 'spare' as a valid status for papers that are duplicates
--   2. When a paper is approved for same grade+subject, other papers auto-marked as spare
--   3. Spare papers can be restored to submitted status later if needed

-- Step 1: Drop old status check constraint
ALTER TABLE public.question_papers
DROP CONSTRAINT IF EXISTS question_papers_status_check;

-- Step 2: Add new constraint with 'spare' status included
ALTER TABLE public.question_papers
ADD CONSTRAINT question_papers_status_check CHECK (
  status = ANY (ARRAY['draft'::text, 'submitted'::text, 'approved'::text, 'rejected'::text, 'spare'::text])
);

-- Step 3: Document the new status
COMMENT ON CONSTRAINT question_papers_status_check ON public.question_papers IS
'Valid paper statuses:
- draft: Local, unpublished
- submitted: Awaiting review
- approved: Selected for printing (only one per grade+subject+academic_year)
- rejected: Returned with feedback
- spare: Marked as backup/spare (auto-set when another paper approved for same grade+subject)';
