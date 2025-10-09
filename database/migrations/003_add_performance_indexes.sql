-- Migration: Add performance indexes for production
-- Purpose: Optimize frequently used queries
-- Version: 2.0.0
-- Date: 2025-01-XX

-- ============================================
-- Question Papers Table Indexes
-- ============================================

-- Most common query: Get papers by tenant, status, and date
CREATE INDEX IF NOT EXISTS idx_question_papers_tenant_status_created
  ON question_papers(tenant_id, status, created_at DESC);

-- User's own papers by status
CREATE INDEX IF NOT EXISTS idx_question_papers_tenant_user_status
  ON question_papers(tenant_id, user_id, status);

-- Approved papers by subject and grade (for question bank)
CREATE INDEX IF NOT EXISTS idx_question_papers_subject_grade
  ON question_papers(subject_id, grade_id)
  WHERE status = 'approved';

-- Paper search by title (full-text search)
CREATE INDEX IF NOT EXISTS idx_question_papers_search
  ON question_papers USING gin(to_tsvector('english', title));

-- Papers for review (submitted status)
CREATE INDEX IF NOT EXISTS idx_question_papers_review
  ON question_papers(tenant_id, status, submitted_at DESC)
  WHERE status = 'submitted';

-- User's submissions
CREATE INDEX IF NOT EXISTS idx_question_papers_user_submissions
  ON question_papers(user_id, status, submitted_at DESC)
  WHERE status IN ('submitted', 'approved', 'rejected');

-- ============================================
-- Questions Table Indexes
-- ============================================

-- Get all questions for a paper (for PDF generation)
CREATE INDEX IF NOT EXISTS idx_questions_paper_section
  ON questions(paper_id, section_name, question_order);

-- Get questions by type
CREATE INDEX IF NOT EXISTS idx_questions_type
  ON questions(paper_id, type);

-- ============================================
-- Users and Roles Indexes
-- ============================================

-- Look up user by tenant (for admin queries)
-- Note: This is on auth.users, may require RLS adjustment
-- CREATE INDEX IF NOT EXISTS idx_users_tenant
--   ON auth.users((raw_user_meta_data->>'tenant_id'));

-- ============================================
-- Subjects and Grades Indexes
-- ============================================

-- Subjects by tenant (already covered by tenant_id index)
CREATE INDEX IF NOT EXISTS idx_subjects_tenant
  ON subjects(tenant_id, name);

-- Grades by tenant
CREATE INDEX IF NOT EXISTS idx_grades_tenant
  ON grades(tenant_id, grade_order);

-- ============================================
-- Update Table Statistics
-- ============================================

-- Analyze tables for query planner optimization
ANALYZE question_papers;
ANALYZE questions;
ANALYZE paper_rejection_history;
ANALYZE subjects;
ANALYZE grades;

-- ============================================
-- Verify Indexes Created
-- ============================================

SELECT
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('question_papers', 'questions', 'paper_rejection_history', 'subjects', 'grades')
ORDER BY tablename, indexname;

-- ============================================
-- Performance Notes
-- ============================================

COMMENT ON INDEX idx_question_papers_tenant_status_created IS
  'Optimizes main paper listing queries by tenant and status';

COMMENT ON INDEX idx_question_papers_search IS
  'Enables full-text search on paper titles';

COMMENT ON INDEX idx_questions_paper_section IS
  'Optimizes PDF generation queries that fetch all questions for a paper';
