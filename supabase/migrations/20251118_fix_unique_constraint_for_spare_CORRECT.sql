-- Migration: Fix unique constraint to properly allow spare papers
-- Date: 2025-11-18
-- Purpose: Allow one approved paper + multiple spare/submitted papers for same grade/subject combo
-- Fix: Remove title/section from uniqueness check - only enforce uniqueness on (tenant, subject, grade, year)

-- Step 1: Drop the old problematic index that includes title/section
DROP INDEX IF EXISTS public.idx_question_papers_unique_with_section;

-- Step 2: Create new unique index that ONLY checks (tenant, subject, grade, year)
-- This allows: 1 approved + multiple spares + multiple submitted for same grade+subject
CREATE UNIQUE INDEX IF NOT EXISTS idx_question_papers_unique_approved_per_grade_subject
ON public.question_papers(tenant_id, subject_id, grade_id, academic_year)
WHERE status = 'approved'::text;

-- Step 3: Document the change
COMMENT ON INDEX public.idx_question_papers_unique_approved_per_grade_subject IS
'Ensures only ONE APPROVED paper per (tenant, subject, grade, academic_year).
Allows multiple SUBMITTED papers (pending review) for the same combination.
Allows multiple SPARE papers (backups) for the same combination.
Does not restrict DRAFT or REJECTED papers.';
