# Quick Start: Grade-Section-Subject Control

## 📋 What You Need to Do

You have **two options**: Keep it simple OR get full control.

---

## ✅ Option 1: Keep It Simple (Currently Working)

**Status**: ✅ Already active - no action needed!

Your app currently filters subjects by grade level based on `subject_catalog.min_grade` and `subject_catalog.max_grade`.

**What you see**:
- Grade 1: 7 subjects (Tamil, Social, Science, Math, Islamiat, English, EVS)
- Grade 6: 9 subjects (+ Computer Science)
- Grade 9: 12 subjects (+ Physics, Chemistry, Biology, Economics)

**No setup needed** - just use the app as-is.

---

## 🎯 Option 2: Full Control Per Section (5-10 minutes)

Use this if you want **different subjects in different sections** of the same grade.

### Step A: Deploy Database Table (2 minutes)

1. Go to **Supabase Console** → **SQL Editor**
2. Copy this entire file content:
   - `supabase/migrations/20251104_create_grade_section_subject.sql`
3. Paste it in Supabase SQL Editor
4. Click **Run**

✅ Table created!

### Step B: Populate with Your Data (3-8 minutes)

Back in **Supabase SQL Editor**, run this query:

```sql
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
  WHERE g.tenant_id = 'f164e8a2-9f54-4231-b33d-e882a209ff06'
  AND gs.tenant_id = 'f164e8a2-9f54-4231-b33d-e882a209ff06'
  AND s.tenant_id = 'f164e8a2-9f54-4231-b33d-e882a209ff06'
  AND gs.grade_id = g.id
  AND g.grade_number >= c.min_grade
  AND g.grade_number <= c.max_grade
)
SELECT tenant_id, grade_id, section_name, subject_id, true, display_order
FROM grade_subjects
ON CONFLICT (tenant_id, grade_id, section, subject_id) DO NOTHING;
```

**IMPORTANT**: Replace `'YOUR-TENANT-ID'` with your actual tenant ID.

**How to find your Tenant ID**:
```sql
SELECT id, name FROM tenants LIMIT 1;
```
Copy the `id` value and paste it in the query above (replace 'YOUR-TENANT-ID').

✅ Data populated!

### Step C: Verify It Worked (1 minute)

Run this to check:
```sql
SELECT
  g.grade_number,
  gs.section_name,
  c.subject_name
FROM grade_section_subject gss
JOIN grades g ON gss.grade_id = g.id
JOIN grade_sections gs ON gss.grade_id = gs.grade_id AND gss.section = gs.section_name
JOIN subjects s ON gss.subject_id = s.id
JOIN subject_catalog c ON s.catalog_subject_id = c.id
WHERE gss.tenant_id = 'YOUR-TENANT-ID'
ORDER BY g.grade_number, gs.section_name, c.subject_name
LIMIT 20;
```

You should see output like:
```
grade_number | section_name | subject_name
1            | A            | English
1            | A            | Islamiat
1            | A            | Mathematics
...
```

✅ Data looks good!

---

## 🎮 Test in App

1. Run: `flutter run`
2. Click a teacher → "Add Assignment"
3. Select a grade
4. You now have per-section subject control!

---

## 📊 Understanding Your Data

### Subjects by Grade (Current Fallback):

| Grade | Min | Max | Subjects | Count |
|-------|-----|-----|----------|-------|
| 1-3   | 1   | 5   | Tamil, Social, Science, Mathematics, Islamiat, English, EVS | 7 |
| 6-8   | 6   | 12  | + Computer Science | 9 |
| 9-12  | 9   | 12  | + Physics, Chemistry, Biology, Economics | 12 |

### What grade_section_subject Does:

Override the above with **per-section** customization:
- Grade 8 Section A: Different subjects than Grade 8 Section B
- Grade 9 Science Section: Can include advanced subjects
- Grade 9 Arts Section: Can exclude Physics/Chemistry

---

## ❓ Frequently Asked Questions

**Q: Do I have to do this?**
A: No! The fallback (Option 1) works fine. Do this only if you need per-section control.

**Q: What if I make a mistake?**
A: You can delete rows from the `grade_section_subject` table and the app will fall back to grade-level filtering.

**Q: Can I edit subjects later?**
A: Yes! Just go to Supabase Dashboard → grade_section_subject table → edit/delete/add rows.

**Q: Can I delete the grade_section_subject table?**
A: Yes, the app will work fine without it (uses fallback).

**Q: How do I add new subjects to grade_section_subject?**
A:
1. Supabase Dashboard → grade_section_subject table
2. Click "Insert new row"
3. Fill in: tenant_id, grade_id, section, subject_id, is_offered=true, display_order=N

**Q: Why 7 subjects for Grade 1 but only some for Grade 9?**
A: Based on subject_catalog min_grade/max_grade ranges. EVS is 1-5 only, Physics is 9-12 only, etc.

---

## 📝 Files You Have

1. **Migrations** (in `supabase/migrations/`):
   - `20251104_create_grade_section_subject.sql` - Table creation
   - `20251104_seed_grade_section_subjects.sql` - Seed template

2. **Documentation**:
   - `GRADE_SECTION_SUBJECT_SETUP.md` - Detailed setup guide
   - `IMPLEMENTATION_SUMMARY.md` - Complete technical overview
   - `QUICK_START_GUIDE.md` - This file

3. **Code Changes**:
   - `lib/features/catalog/data/datasources/subject_data_source.dart`
   - `lib/features/catalog/presentation/bloc/subject_bloc.dart`
   - `lib/features/assignments/presentation/widgets/assignment_editor_modal.dart`
   - `lib/features/assignments/presentation/pages/teacher_assignment_detail_page_new.dart`

---

## 🚀 Decision Tree

```
Do you need per-section subject control?
├─ NO  → You're done! Current fallback works great ✅
└─ YES →
   ├─ Follow Option 2 above (5-10 minutes)
   └─ Done! ✅
```

---

## 📞 Need More Help?

- **Setup Questions**: See `GRADE_SECTION_SUBJECT_SETUP.md`
- **Technical Details**: See `IMPLEMENTATION_SUMMARY.md`
- **Code Location**: Check files listed in "Files You Have" section

---

**Status**: ✅ Ready to use (either way!)
