-- =====================================================
-- EXAM TIMETABLE SYSTEM - ROW LEVEL SECURITY POLICIES
-- =====================================================
-- This migration sets up RLS policies for exam tables
-- Policies ensure tenants can only see/modify their own data
-- and admins have full access
-- =====================================================

-- ===== ENABLE RLS ON ALL EXAM TABLES =====
ALTER TABLE exam_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_timetable_entries ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "exam_calendar_select_own_tenant" ON exam_calendar;
DROP POLICY IF EXISTS "exam_calendar_insert_admin_only" ON exam_calendar;
DROP POLICY IF EXISTS "exam_calendar_update_admin_only" ON exam_calendar;
DROP POLICY IF EXISTS "exam_calendar_delete_admin_only" ON exam_calendar;
DROP POLICY IF EXISTS "exam_timetables_select_own_tenant" ON exam_timetables;
DROP POLICY IF EXISTS "exam_timetables_insert_admin_only" ON exam_timetables;
DROP POLICY IF EXISTS "exam_timetables_update_admin_only" ON exam_timetables;
DROP POLICY IF EXISTS "exam_timetables_delete_admin_only" ON exam_timetables;
DROP POLICY IF EXISTS "exam_timetable_entries_select_own_tenant" ON exam_timetable_entries;
DROP POLICY IF EXISTS "exam_timetable_entries_insert_admin_only" ON exam_timetable_entries;
DROP POLICY IF EXISTS "exam_timetable_entries_update_admin_only" ON exam_timetable_entries;
DROP POLICY IF EXISTS "exam_timetable_entries_delete_admin_only" ON exam_timetable_entries;
DROP POLICY IF EXISTS "question_papers_select_assigned_entries" ON question_papers;


-- ===== EXAM_CALENDAR POLICIES =====

-- Policy: Users can SELECT exam calendars of their tenant
CREATE POLICY "exam_calendar_select_own_tenant"
ON exam_calendar
FOR SELECT
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
);

-- Policy: Only admins can INSERT exam calendars
CREATE POLICY "exam_calendar_insert_admin_only"
ON exam_calendar
FOR INSERT
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Only admins can UPDATE exam calendars
CREATE POLICY "exam_calendar_update_admin_only"
ON exam_calendar
FOR UPDATE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
)
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Only admins can DELETE exam calendars
CREATE POLICY "exam_calendar_delete_admin_only"
ON exam_calendar
FOR DELETE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);


-- ===== EXAM_TIMETABLES POLICIES =====

-- Policy: Users can SELECT exam timetables of their tenant
CREATE POLICY "exam_timetables_select_own_tenant"
ON exam_timetables
FOR SELECT
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
);

-- Policy: Only admins can INSERT exam timetables
CREATE POLICY "exam_timetables_insert_admin_only"
ON exam_timetables
FOR INSERT
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
  AND created_by = auth.uid()
);

-- Policy: Only admins can UPDATE exam timetables
CREATE POLICY "exam_timetables_update_admin_only"
ON exam_timetables
FOR UPDATE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
)
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Only admins can DELETE exam timetables
CREATE POLICY "exam_timetables_delete_admin_only"
ON exam_timetables
FOR DELETE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);


-- ===== EXAM_TIMETABLE_ENTRIES POLICIES =====

-- Policy: Users can SELECT entries from timetables of their tenant
CREATE POLICY "exam_timetable_entries_select_own_tenant"
ON exam_timetable_entries
FOR SELECT
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
);

-- Policy: Only admins can INSERT entries
CREATE POLICY "exam_timetable_entries_insert_admin_only"
ON exam_timetable_entries
FOR INSERT
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Only admins can UPDATE entries
CREATE POLICY "exam_timetable_entries_update_admin_only"
ON exam_timetable_entries
FOR UPDATE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
)
WITH CHECK (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Policy: Only admins can DELETE entries
CREATE POLICY "exam_timetable_entries_delete_admin_only"
ON exam_timetable_entries
FOR DELETE
USING (
  tenant_id = (
    SELECT tenant_id FROM profiles
    WHERE id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);


-- ===== QUESTION_PAPERS RLS UPDATE =====
-- Update question_papers policies to consider exam_timetable_entry_id

-- Add SELECT policy allowing teachers to see papers assigned to them via timetable entry
DROP POLICY IF EXISTS "question_papers_select_assigned_entries" ON question_papers;
CREATE POLICY "question_papers_select_assigned_entries"
ON question_papers
FOR SELECT
USING (
  exam_timetable_entry_id IS NULL -- Allow existing papers without timetable entry
  OR EXISTS (
    SELECT 1 FROM exam_timetable_entries
    WHERE id = question_papers.exam_timetable_entry_id
    AND (
      assigned_teacher_id = auth.uid()
      OR (
        SELECT role FROM profiles WHERE id = auth.uid()
      ) = 'admin'
    )
  )
);


-- ===== COMMENTS FOR DOCUMENTATION =====
COMMENT ON POLICY "exam_calendar_select_own_tenant" ON exam_calendar
IS 'All users can view exam calendars for their tenant';

COMMENT ON POLICY "exam_timetables_insert_admin_only" ON exam_timetables
IS 'Only admins can create new timetables';

COMMENT ON POLICY "exam_timetable_entries_select_own_tenant" ON exam_timetable_entries
IS 'All users can view timetable entries for their tenant';

COMMENT ON POLICY "exam_timetable_entries_insert_admin_only" ON exam_timetable_entries
IS 'Only admins can add exam entries to timetables';
