-- Create paper_rejection_history table to track rejection history
-- This allows us to edit papers in place while preserving rejection history

CREATE TABLE IF NOT EXISTS paper_rejection_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    rejection_reason TEXT NOT NULL,
    rejected_by UUID NOT NULL REFERENCES auth.users(id),
    rejected_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revision_number INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure we have a unique revision number per paper
    CONSTRAINT unique_paper_revision UNIQUE (paper_id, revision_number)
);

-- Create index for faster lookups by paper_id
CREATE INDEX idx_paper_rejection_history_paper_id ON paper_rejection_history(paper_id);

-- Create index for faster lookups by rejected_by
CREATE INDEX idx_paper_rejection_history_rejected_by ON paper_rejection_history(rejected_by);

-- Enable Row Level Security
ALTER TABLE paper_rejection_history ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view rejection history for their own papers
CREATE POLICY "Users can view rejection history for their own papers"
    ON paper_rejection_history
    FOR SELECT
    USING (
        paper_id IN (
            SELECT id FROM question_papers
            WHERE user_id = auth.uid()
        )
    );

-- Policy: Admins can view all rejection history
CREATE POLICY "Admins can view all rejection history"
    ON paper_rejection_history
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM user_tenants
            WHERE user_id = auth.uid()
            AND role = 'admin'
        )
    );

-- Policy: System can insert rejection history (service role)
CREATE POLICY "System can insert rejection history"
    ON paper_rejection_history
    FOR INSERT
    WITH CHECK (true);

-- Add comment to table
COMMENT ON TABLE paper_rejection_history IS 'Stores history of paper rejections to track revisions when papers are edited in place';
COMMENT ON COLUMN paper_rejection_history.revision_number IS 'Incremental number tracking how many times this paper has been rejected';
