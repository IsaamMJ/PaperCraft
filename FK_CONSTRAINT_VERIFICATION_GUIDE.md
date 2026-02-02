# Foreign Key Constraint Verification Guide

## Issue
The `exam_timetable_entries.grade_section_id` column has a FK constraint to the `grade_sections` table. If this table is empty or the IDs don't match, the timetable creation will fail.

---

## STEP 1: Verify Grade Sections Exist

Run this query in Supabase SQL Editor:

```sql
-- Check if grade_sections are populated
SELECT
  gs.id as grade_section_id,
  g.grade_number,
  gs.section_name,
  gs.is_active,
  COUNT(DISTINCT gss.subject_id) as subject_count
FROM grade_sections gs
LEFT JOIN grades g ON gs.grade_id = g.id
LEFT JOIN grade_section_subject gss ON gs.id = gss.grade_id
  AND gs.section_name = gss.section
WHERE gs.is_active = true
GROUP BY gs.id, g.grade_number, gs.section_name, gs.is_active
ORDER BY g.grade_number, gs.section_name;
```

**Expected Result:**
- At least 1 row per grade (e.g., 10-A, 10-B, 10-C)
- `subject_count` > 0 (means subjects are assigned)

**If empty or few rows → Run Step 2**

---

## STEP 2: Populate Grade Sections (If Missing)

### Option A: Automatic Population (Recommended)

If you have grades already set up, run this to auto-generate all sections:

```sql
-- This will create sections A, B, C for each grade
INSERT INTO grade_sections (tenant_id, grade_id, section_name, display_order, is_active)
SELECT DISTINCT
  g.tenant_id,
  g.id as grade_id,
  section.name as section_name,
  section.order as display_order,
  true
FROM grades g
CROSS JOIN (
  VALUES
    ('A', 1),
    ('B', 2),
    ('C', 3)
) section(name, order)
WHERE g.is_active = true
ON CONFLICT (tenant_id, grade_id, section_name) DO NOTHING;
```

### Option B: Manual Entry via Supabase Dashboard

1. Go to Supabase Dashboard → SQL Editor
2. Find the `grade_sections` table
3. Insert rows like this:
   ```
   tenant_id: (your tenant UUID)
   grade_id: (grade UUID from grades table)
   section_name: A, B, or C
   display_order: 1, 2, 3
   is_active: true
   ```

---

## STEP 3: Assign Subjects to Sections (If Empty)

After populating grade_sections, assign subjects:

```sql
-- Assign subjects to grade-section combinations based on grade level
INSERT INTO grade_section_subject (tenant_id, grade_id, section, subject_id, is_offered, display_order, created_at, updated_at)
SELECT
  g.tenant_id,
  g.id as grade_id,
  gs.section_name,
  s.id as subject_id,
  true,
  ROW_NUMBER() OVER (PARTITION BY g.id, gs.section_name ORDER BY c.subject_name) as display_order,
  NOW(),
  NOW()
FROM grades g
CROSS JOIN grade_sections gs
CROSS JOIN subjects s
JOIN subject_catalog c ON s.catalog_subject_id = c.id
WHERE g.tenant_id = gs.tenant_id
  AND g.id = gs.grade_id
  AND s.tenant_id = g.tenant_id
  AND g.is_active = true
  AND gs.is_active = true
  AND s.is_active = true
  AND c.is_active = true
  -- Only assign subjects within grade range
  AND g.grade_number >= c.min_grade
  AND g.grade_number <= c.max_grade
ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;
```

---

## STEP 4: Verify Everything Is Ready

Run this final check:

```sql
-- Final verification before creating timetable
SELECT
  COUNT(DISTINCT gs.id) as total_grade_sections,
  COUNT(DISTINCT gss.subject_id) as total_subject_assignments
FROM grade_sections gs
LEFT JOIN grade_section_subject gss ON gs.id = gss.grade_id
WHERE gs.is_active = true;

-- Should show:
-- total_grade_sections: >= number of grades
-- total_subject_assignments: >= total_grade_sections * 3 (assuming 3+ subjects per section)
```

---

## STEP 5: Test Timetable Creation

If all checks pass, try creating a timetable. The FK constraint should now be satisfied!

**If it still fails**, check the error message:
- `"violates foreign key constraint"` → Grade sections are missing
- `"No sections found for selected grades"` → Run the insert script above
- Other error → Check logs in BLoC debug output

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| No grade_sections found | DB not seeded | Run Step 2 Option A |
| Foreign key violation | Invalid grade_section_id | Verify Step 1 results |
| No subjects assigned | grade_section_subject empty | Run Step 3 |
| Wrong subject list | Subject not in catalog range | Check min_grade/max_grade in subject_catalog |

