-- =====================================================
-- ADD SUBJECT VALIDATION FOR TIMETABLE
-- =====================================================
-- This migration creates validation functions and views to ensure
-- exam timetable entries only use subjects that are configured
-- in the academic structure (grade_section_subject table).
--
-- Problem: Users could assign subjects to grades that don't have
--          those subjects configured in academic structure.
--
-- Example: Grade 1 has EVS assigned, but user tries to assign Science
--          Solution: Validation function checks grade_section_subject table

-- Step 1: Create a helper function to check if a subject assignment is valid
-- Usage: SELECT is_valid_subject_for_grade_section('tenant-id', 'grade-id', 'A', 'subject-id')
CREATE OR REPLACE FUNCTION is_valid_subject_for_grade_section(
  p_tenant_id UUID,
  p_grade_id UUID,
  p_section TEXT,
  p_subject_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM grade_section_subject
    WHERE tenant_id = p_tenant_id
      AND grade_id = p_grade_id
      AND section = p_section
      AND subject_id = p_subject_id
      AND is_offered = true
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Step 2: Create a view for valid timetable entries
-- This view shows all valid (grade_id, section, subject_id) combinations
-- that can be assigned in timetable entries, filtered by is_offered = true
CREATE OR REPLACE VIEW valid_timetable_entries AS
SELECT DISTINCT
  gss.tenant_id,
  gss.grade_id,
  gss.section,
  gss.subject_id,
  (SELECT subject_name FROM subject_catalog WHERE id = s.catalog_subject_id) as subject_name
FROM grade_section_subject gss
JOIN subjects s ON gss.subject_id = s.id AND gss.tenant_id = s.tenant_id
WHERE gss.is_offered = true
  AND s.is_active = true;

-- Step 3: Create a function to validate all entries in a timetable
-- This function checks if all timetable entries have valid subject assignments
-- in the grade_section_subject table.
--
-- Usage: SELECT * FROM validate_timetable_entries('timetable-id')
-- Returns: is_valid BOOLEAN, error_message TEXT
CREATE OR REPLACE FUNCTION validate_timetable_entries(
  p_timetable_id UUID
) RETURNS TABLE(is_valid BOOLEAN, error_message TEXT) AS $$
DECLARE
  v_invalid_entry_count INT;
  v_error_msg TEXT;
  v_invalid_entries TEXT;
BEGIN
  -- Check if all entries have valid subject assignments in grade_section_subject
  SELECT COUNT(*) INTO v_invalid_entry_count
  FROM exam_timetable_entries ete
  WHERE ete.timetable_id = p_timetable_id
    AND NOT EXISTS (
      SELECT 1
      FROM grade_section_subject gss
      WHERE gss.tenant_id = ete.tenant_id
        AND gss.grade_id = ete.grade_id
        AND gss.section = ete.section
        AND gss.subject_id = ete.subject_id
        AND gss.is_offered = true
    );

  IF v_invalid_entry_count > 0 THEN
    -- Get details of invalid entries
    SELECT STRING_AGG(DISTINCT 'Grade ' || ete.grade_id || ' Section ' || ete.section || ' Subject ' || ete.subject_id, ', ')
    INTO v_invalid_entries
    FROM exam_timetable_entries ete
    WHERE ete.timetable_id = p_timetable_id
      AND NOT EXISTS (
        SELECT 1
        FROM grade_section_subject gss
        WHERE gss.tenant_id = ete.tenant_id
          AND gss.grade_id = ete.grade_id
          AND gss.section = ete.section
          AND gss.subject_id = ete.subject_id
          AND gss.is_offered = true
      );

    v_error_msg := 'Timetable has ' || v_invalid_entry_count || ' invalid entries. ' || COALESCE(v_invalid_entries, '');
    RETURN QUERY SELECT false, v_error_msg;
  ELSE
    RETURN QUERY SELECT true, 'All entries are valid'::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;
