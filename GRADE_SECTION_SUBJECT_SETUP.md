# Grade-Section-Subject Setup Guide

This guide helps you populate the `grade_section_subject` table to control which subjects are offered in each grade+section combination.

## Step 1: Get Your Database IDs

Go to Supabase Console and run these queries in the SQL Editor to get all necessary IDs:

### Get Tenant ID
```sql
SELECT id, name FROM tenants LIMIT 1;
```
Copy the `id` value - you'll need this for all other queries.

### Get Grades (replace 'YOUR-TENANT-ID')
```sql
SELECT id, grade_number FROM grades
WHERE tenant_id = 'YOUR-TENANT-ID'
ORDER BY grade_number;
```
This shows all grades in your school. Example output:
```
id                                   | grade_number
-------------------------------------+-----------
550e8400-e29b-41d4-a716-446655440001 | 1
550e8400-e29b-41d4-a716-446655440002 | 2
550e8400-e29b-41d4-a716-446655440003 | 3
550e8400-e29b-41d4-a716-446655440006 | 6
550e8400-e29b-41d4-a716-446655440009 | 9
```

### Get Grade Sections (replace 'YOUR-TENANT-ID')
```sql
SELECT id, grade_id, section_name FROM grade_sections
WHERE tenant_id = 'YOUR-TENANT-ID'
ORDER BY grade_id, section_name;
```
This shows all sections in each grade. Example output:
```
id                                   | grade_id                             | section_name
-------------------------------------+--------------------------------------+-----------
650e8400-e29b-41d4-a716-446655440001 | 550e8400-e29b-41d4-a716-446655440001 | A
650e8400-e29b-41d4-a716-446655440002 | 550e8400-e29b-41d4-a716-446655440001 | B
650e8400-e29b-41d4-a716-446655440003 | 550e8400-e29b-41d4-a716-446655440001 | C
```

### Get Subjects (replace 'YOUR-TENANT-ID')
```sql
SELECT s.id, c.subject_name, c.min_grade, c.max_grade
FROM subjects s
JOIN subject_catalog c ON s.catalog_subject_id = c.id
WHERE s.tenant_id = 'YOUR-TENANT-ID'
ORDER BY c.subject_name;
```
This shows all subjects in your school with their grade ranges. Example output:
```
id                                   | subject_name    | min_grade | max_grade
-------------------------------------+-----------------+-----------+----------
750e8400-e29b-41d4-a716-446655440001 | Tamil           |         1 |        12
750e8400-e29b-41d4-a716-446655440002 | Mathematics     |         1 |        12
750e8400-e29b-41d4-a716-446655440003 | English         |         1 |        12
750e8400-e29b-41d4-a716-446655440004 | Science         |         1 |        12
750e8400-e29b-41d4-a716-446655440005 | Physics         |         9 |        12
750e8400-e29b-41d4-a716-446655440006 | Chemistry       |         9 |        12
750e8400-e29b-41d4-a716-446655440007 | Biology         |         9 |        12
```

## Step 2: Choose Your Seeding Strategy

### Option A: Same Subjects for All Sections (EASIEST)
Use this if all sections in a grade have the same subjects:

```sql
-- Replace YOUR-TENANT-ID with your actual tenant ID
INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order)
WITH grade_subjects AS (
  SELECT
    'YOUR-TENANT-ID'::uuid as tenant_id,
    g.id as grade_id,
    gs.section_name,
    s.id as subject_id,
    ROW_NUMBER() OVER (PARTITION BY g.id, gs.section_name ORDER BY c.subject_name) as display_order
  FROM grades g
  CROSS JOIN grade_sections gs
  CROSS JOIN subjects s
  JOIN subject_catalog c ON s.catalog_subject_id = c.id
  WHERE g.tenant_id = 'YOUR-TENANT-ID'
  AND gs.tenant_id = 'YOUR-TENANT-ID'
  AND s.tenant_id = 'YOUR-TENANT-ID'
  AND gs.grade_id = g.id
  AND g.grade_number >= c.min_grade
  AND g.grade_number <= c.max_grade
  AND c.is_active = true
  AND s.is_active = true
)
SELECT tenant_id, grade_id, section_name, subject_id, true, display_order
FROM grade_subjects
ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;
```

This automatically:
- Takes all grades from your school
- For each section in each grade
- Assigns all subjects that match that grade's min/max range
- Orders them alphabetically

### Option B: Manual GUI Entry
1. Go to Supabase Console
2. Navigate to the `grade_section_subject` table
3. Click "Insert" to add rows manually
4. Fill in:
   - `tenant_id`: Your tenant UUID
   - `grade_id`: Grade UUID from Step 1
   - `section`: Section name (A, B, C, etc.)
   - `subject_id`: Subject UUID from Step 1
   - `is_offered`: true
   - `display_order`: 1, 2, 3, etc. (for ordering)

### Option C: Specific Subjects per Grade+Section
If different sections need different subjects, create a custom INSERT:

```sql
-- Grade 1 Section A: Tamil, Mathematics, English, Science, Islamiat, Social, EVS
INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order)
VALUES
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'TAMIL-ID', true, 1),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'MATH-ID', true, 2),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'ENGLISH-ID', true, 3),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'SCIENCE-ID', true, 4),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'ISLAMIAT-ID', true, 5),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'SOCIAL-ID', true, 6),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'A', 'EVS-ID', true, 7)
ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;

-- Grade 1 Section B: Same subjects
INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order)
VALUES
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'B', 'TAMIL-ID', true, 1),
  ('YOUR-TENANT-ID', 'GRADE-1-ID', 'B', 'MATH-ID', true, 2),
  -- ... repeat for other subjects
ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;
```

## Step 3: Verify the Data

After populating, verify with this query:

```sql
SELECT
  g.grade_number,
  gs.section_name,
  c.subject_name,
  gss.display_order
FROM grade_section_subject gss
JOIN grades g ON gss.grade_id = g.id
JOIN grade_sections gs ON gss.grade_id = gs.grade_id AND gss.section = gs.section_name
JOIN subjects s ON gss.subject_id = s.id
JOIN subject_catalog c ON s.catalog_subject_id = c.id
WHERE gss.tenant_id = 'YOUR-TENANT-ID'
ORDER BY g.grade_number, gs.section_name, gss.display_order;
```

Expected output:
```
grade_number | section_name | subject_name    | display_order
-------------|--------------|-----------------|---------------
1            | A            | English         | 1
1            | A            | Islamiat        | 2
1            | A            | Mathematics     | 3
1            | A            | Science         | 4
1            | A            | Social          | 5
1            | A            | Tamil           | 6
1            | A            | EVS             | 7
1            | B            | English         | 1
...
```

## Step 4: Test in the App

1. Run the app: `flutter run`
2. Click a teacher
3. Click "Add Assignment"
4. Select a grade
5. Select a section
6. You should now see only the subjects configured for that grade+section combo!

## What if the table is empty?

If you don't populate `grade_section_subject`, the app falls back to using `subject_catalog.min_grade` and `subject_catalog.max_grade` ranges. This means all subjects available for a grade level are shown for all sections.

## Common Patterns

### All Sections in a Grade Have Same Subjects (TYPICAL)
Run Option A above - it automatically handles this case.

### Some Grades Have Different Subjects Per Section
Use Option C with custom INSERT statements for each combination.

### Two Grade Ranges
Group 1: Grades 1-3 (Primary) - 7 subjects
Group 2: Grades 6-9 (Secondary) - 10 subjects

Use Option A, it automatically groups by min_grade/max_grade.

## Troubleshooting

**Q: I'm getting foreign key errors**
A: Make sure the grade_id, section, subject_id, and tenant_id actually exist in your database. Double-check the UUIDs from Step 1.

**Q: The query is returning no data**
A: Your tenant_id might be wrong. Try querying just tenants first to confirm it exists.

**Q: Section name is wrong**
A: Use the actual section names from the grade_sections table (case-sensitive). Typically: A, B, C or 1, 2, 3.

## Summary

After following these steps:
- ✅ `grade_section_subject` table will be created
- ✅ You'll have all necessary IDs
- ✅ You can populate subjects for each grade+section
- ✅ The app will show only relevant subjects per section
