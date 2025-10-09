-- Migration: Create paper_rejection_history table
-- Purpose: Track rejection history when papers are edited in place
-- Version: 2.0.0
-- Date: 2025-01-XX

-- Create the table
CREATE TABLE IF NOT EXISTS paper_rejection_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    rejection_reason TEXT NOT NULL,
    rejected_by UUID NOT NULL REFERENCES auth.users(id),
    rejected_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revision_number INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure unique revision numbers per paper
    CONSTRAINT unique_paper_revision UNIQUE (paper_id, revision_number)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_paper_rejection_history_paper_id
  ON paper_rejection_history(paper_id);

CREATE INDEX IF NOT EXISTS idx_paper_rejection_history_rejected_by
  ON paper_rejection_history(rejected_by);

CREATE INDEX IF NOT EXISTS idx_paper_rejection_history_paper_revision
  ON paper_rejection_history(paper_id, revision_number DESC);

-- Enable Row Level Security
ALTER TABLE paper_rejection_history ENABLE ROW LEVEL SECURITY;

-- RLS Policy 1: Users can view rejection history of their own papers
CREATE POLICY "Users can view rejection history of their own papers"
  ON paper_rejection_history FOR SELECT
  USING (
    paper_id IN (
      SELECT id FROM question_papers
      WHERE user_id = auth.uid()
    )
  );

-- RLS Policy 2: Admins can view all rejection history in their tenant
CREATE POLICY "Admins can view all rejection history"
  ON paper_rejection_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );

-- RLS Policy 3: System can insert rejection history (used by backend)
CREATE POLICY "System can insert rejection history"
  ON paper_rejection_history FOR INSERT
  WITH CHECK (
    -- Only allow insert if the user is an admin rejecting a paper
    EXISTS (
      SELECT 1 FROM auth.users
      WHERE auth.users.id = auth.uid()
      AND auth.users.raw_user_meta_data->>'role' IN ('admin', 'super_admin')
    )
  );

-- Add comment for documentation
COMMENT ON TABLE paper_rejection_history IS
  'Tracks rejection history for papers that are edited in place. '
  'When a paper is rejected and then edited, the rejection reason is saved here '
  'before converting the paper back to draft status.';

-- Verify the table was created
SELECT
  'paper_rejection_history table created successfully' AS status,
  COUNT(*) AS existing_records
FROM paper_rejection_history;
