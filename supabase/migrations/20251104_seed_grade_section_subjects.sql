-- Seed grade_section_subject table with default subject assignments
-- This script populates which subjects are offered in each grade and section combination

-- NOTE: This is a TEMPLATE. You need to replace the UUID values with actual IDs from your database.
-- To get the actual IDs, run these queries in Supabase:
--
-- SELECT id, grade_number FROM grades WHERE tenant_id = 'your-tenant-id' ORDER BY grade_number;
-- SELECT id, section_name FROM grade_sections WHERE tenant_id = 'your-tenant-id' ORDER BY grade_number, section_name;
-- SELECT s.id, c.subject_name FROM subjects s JOIN subject_catalog c ON s.catalog_subject_id = c.id
--   WHERE s.tenant_id = 'your-tenant-id' ORDER BY c.subject_name;

-- Example data mapping for a typical school structure:
-- Grade 1-3: Tamil, Social, Science, Mathematics, Islamiat, English, EVS
-- Grade 4-5: Tamil, Social, Science, Mathematics, Islamiat, English
-- Grade 6-8: Tamil, Social, Science, Mathematics, Islamiat, English, History, Geography, Computer Science
-- Grade 9-12: Tamil, Social, Science, Mathematics, Islamiat, English, Physics, Chemistry, Biology, Computer Science, Economics

-- For each tenant, grade, and section combination:
-- Grade 1 Sections (A, B, C): All core subjects for primary
-- Grade 2 Sections (A, B, C): All core subjects for primary
-- Grade 3 Sections (A, B, C): All core subjects for primary + History/Geography
-- Grade 6 Sections (A, B, C): Upper primary subjects including specialized sciences
-- Grade 9 Sections (A, B, C): Secondary with specialized sciences

-- HOW TO USE THIS MIGRATION:
-- 1. First, run the create_grade_section_subject.sql migration to create the table
-- 2. Then customize this seed file with your actual UUIDs from Supabase
-- 3. You can insert data manually using the Supabase dashboard or via SQL

-- Example INSERT statement template:
-- INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order)
-- VALUES (
--   'TENANT_UUID',
--   'GRADE_UUID',
--   'A',
--   'SUBJECT_UUID',
--   true,
--   1
-- )
-- ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;

-- To populate this automatically:
-- 1. Get your tenant_id from the tenants table
-- 2. Update the SELECT statements below to use your actual IDs
-- 3. Then customize and run the INSERT statements

-- IMPORTANT: The following is a data population strategy you can use:
-- Copy subjects that match the grade range from subject_catalog

-- Method 1: Bulk insert for all sections using same subject set per grade:
-- For each grade in your school, assign all subjects within its min_grade/max_grade range

-- This is intentionally left as comments because the actual seeding
-- requires your specific database IDs.

-- Once you have the IDs, you can use this pattern:
-- WITH grade_subjects AS (
--   SELECT
--     'your-tenant-id'::uuid as tenant_id,
--     g.id as grade_id,
--     gs.section_name,
--     s.id as subject_id,
--     ROW_NUMBER() OVER (PARTITION BY g.id, gs.section_name ORDER BY c.subject_name) as display_order
--   FROM grades g
--   CROSS JOIN grade_sections gs
--   CROSS JOIN subjects s
--   JOIN subject_catalog c ON s.catalog_subject_id = c.id
--   WHERE g.tenant_id = 'your-tenant-id'
--   AND gs.tenant_id = 'your-tenant-id'
--   AND s.tenant_id = 'your-tenant-id'
--   AND gs.grade_id = g.id
--   AND g.grade_number >= c.min_grade
--   AND g.grade_number <= c.max_grade
--   AND c.is_active = true
-- )
-- INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order)
-- SELECT tenant_id, grade_id, section_name, subject_id, true, display_order
-- FROM grade_subjects
-- ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;

-- If you want to populate from the Supabase UI:
-- 1. Go to the grade_section_subject table
-- 2. Use the Insert button to add rows
-- 3. Select tenant, grade, section, and subject combinations
-- 4. Set is_offered = true for all
-- 5. Set display_order sequentially

-- DEFAULT BEHAVIOR if this table is empty:
-- The app will fall back to filtering subjects based on subject_catalog.min_grade and subject_catalog.max_grade
-- This is equivalent to showing all subjects available for that grade level in all sections
