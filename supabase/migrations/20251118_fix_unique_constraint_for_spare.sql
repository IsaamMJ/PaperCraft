-- Migration: Fix unique constraint to allow spare papers
-- Date: 2025-11-18
-- Purpose: Allow multiple papers (approved + spare) with same grade/subject combo

-- Step 1: Drop the old unique index
DROP INDEX IF EXISTS public.idx_question_papers_unique_with_section;

-- Step 2: Create new unique index that excludes both draft and spare papers
CREATE UNIQUE INDEX IF NOT EXISTS idx_question_papers_unique_with_section
ON public.question_papers(tenant_id, subject_id, grade_id, academic_year, title, COALESCE(section, ''))
WHERE status NOT IN ('draft'::text, 'spare'::text);

-- Step 3: Document the change
COMMENT ON INDEX public.idx_question_papers_unique_with_section IS
'Ensures only one APPROVED or SUBMITTED paper per grade+subject combination.
Allows multiple SPARE papers (backups) for the same combination.
Ignores DRAFT papers from uniqueness check.';
