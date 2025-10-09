-- Add version control and audit logging features
-- Migration: 20250101_add_version_control_and_audit

-- ============================================
-- 1. Add version control to question_papers
-- ============================================

ALTER TABLE question_papers
ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create index for soft-deleted papers
CREATE INDEX IF NOT EXISTS idx_question_papers_deleted
ON question_papers(deleted_at)
WHERE deleted_at IS NOT NULL;

-- ============================================
-- 2. Create audit logs table
-- ============================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  action VARCHAR(50) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id UUID NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. Create indexes for performance
-- ============================================

CREATE INDEX IF NOT EXISTS idx_audit_logs_user
ON audit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
ON audit_logs(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant
ON audit_logs(tenant_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created
ON audit_logs(created_at DESC);

-- ============================================
-- 4. Enable RLS for audit logs
-- ============================================

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own audit logs
CREATE POLICY "Users can view their own audit logs"
  ON audit_logs FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Policy: Only authenticated users can insert audit logs
CREATE POLICY "Authenticated users can insert audit logs"
  ON audit_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================
-- 5. Add function to auto-increment version
-- ============================================

CREATE OR REPLACE FUNCTION increment_paper_version()
RETURNS TRIGGER AS $$
BEGIN
  -- Only increment version if paper is being updated (not inserted)
  IF TG_OP = 'UPDATE' AND OLD.id = NEW.id THEN
    NEW.version := OLD.version + 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-incrementing version
DROP TRIGGER IF EXISTS trigger_increment_paper_version ON question_papers;
CREATE TRIGGER trigger_increment_paper_version
  BEFORE UPDATE ON question_papers
  FOR EACH ROW
  EXECUTE FUNCTION increment_paper_version();

-- ============================================
-- 6. Add function for soft delete
-- ============================================

CREATE OR REPLACE FUNCTION soft_delete_paper()
RETURNS TRIGGER AS $$
BEGIN
  -- If deleted_at is set, this is a soft delete
  -- Prevent hard delete by converting to update
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. Add comments for documentation
-- ============================================

COMMENT ON TABLE audit_logs IS 'Stores audit trail for all admin actions';
COMMENT ON COLUMN audit_logs.action IS 'Action performed: approve_paper, reject_paper, delete_paper, etc.';
COMMENT ON COLUMN audit_logs.entity_type IS 'Type of entity: question_paper, subject, grade, etc.';
COMMENT ON COLUMN audit_logs.metadata IS 'Additional context data in JSON format';

COMMENT ON COLUMN question_papers.version IS 'Version number for optimistic locking';
COMMENT ON COLUMN question_papers.deleted_at IS 'Soft delete timestamp - NULL means not deleted';
