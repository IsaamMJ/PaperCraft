# Migration Scripts to Run - Academic Structure Consistency Fix

## Current Situation
You have many migrations already applied (2025-01 through 2025-11-11). Your timetable feature is mostly working, but needs the academic structure consistency fixes.

---

## ✅ MIGRATIONS TO RUN (In Order)

### **1. REQUIRED - Fixed Migration (Already Run, But May Have Failed)**

**File:** `supabase/migrations/20251111_refactor_timetable_entries_use_grade_sections.sql`

**Status:** ⚠️ NEEDS TO BE RE-RUN (Fixed Version)

**What it does:**
- Adds `grade_section_id` column to `exam_timetable_entries` table
- Maps existing entries to their grade_sections
- Deletes orphaned entries that don't have valid grade_sections
- Adds foreign key constraint to `grade_sections`

**Why re-run?** The original version may have failed because:
- It didn't handle orphaned rows properly
- It tried to set NOT NULL before all rows were populated

**Fixed version now:**
- Adds column as nullable first
- Deletes orphaned entries
- Then makes it NOT NULL
- Then adds foreign key

---

### **2. REQUIRED - New Migration for Subject Validation**

**File:** `supabase/migrations/20251114_add_subject_validation_constraints.sql`

**Status:** ✨ NEW - Needs to be run AFTER the above

**What it does:**
- Adds foreign key constraint: `exam_timetable_entries` → `grade_section_subject`
- Ensures you can only assign subjects that are configured in the academic structure
- Creates indexes for performance
- Creates helper function `is_valid_subject_for_grade_section()`
- Creates view `valid_timetable_entries`

**Impact:**
- Database now prevents invalid subject assignments at the constraint level
- Users cannot assign Science to Grade 1 if Grade 1 only has EVS

---

## ❌ DO NOT RUN

❌ `20251113_add_grade_section_id_column.sql` - DELETED (duplicate)
❌ `20251113_diagnose_timetable_schema.sql` - DELETED (for diagnostics only)

---

## 🚀 HOW TO RUN MIGRATIONS

### **Option 1: Using Supabase CLI (Recommended)**

```bash
# Navigate to your project root
cd "E:\New folder (2)\papercraft"

# Push all pending migrations to Supabase
supabase db push

# This will:
# 1. Detect pending migrations
# 2. Run them in order
# 3. Show you the results
```

---

### **Option 2: Manual SQL Execution**

If CLI doesn't work, manually run in Supabase dashboard:

1. Go to **Supabase Dashboard** → Your Project
2. Go to **SQL Editor**
3. Create a new query
4. Copy the content from: `supabase/migrations/20251111_refactor_timetable_entries_use_grade_sections.sql`
5. Execute it
6. Once successful, copy & execute: `supabase/migrations/20251114_add_subject_validation_constraints.sql`

---

### **Option 3: Reset Everything (If in Development)**

If you're still in development and want a clean slate:

```bash
# This will reset your database to the initial state
supabase db reset

# Then push all migrations fresh:
supabase db push
```

**WARNING:** This will delete all your local Supabase data!

---

## 📊 MIGRATION EXECUTION ORDER

```
20251111_refactor_timetable_entries_use_grade_sections.sql     (FIXED VERSION)
    ↓
20251114_add_subject_validation_constraints.sql                (NEW)
    ↓
✅ Done! Academic consistency is now enforced
```

---

## ✔️ VERIFICATION AFTER RUNNING

After migrations complete, verify they worked:

### **Check 1: Column Exists**
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'exam_timetable_entries'
AND column_name = 'grade_section_id';
-- Should return: grade_section_id
```

### **Check 2: Foreign Key Constraint Exists**
```sql
SELECT constraint_name FROM information_schema.table_constraints
WHERE table_name = 'exam_timetable_entries'
AND constraint_type = 'FOREIGN KEY';
-- Should see: fk_timetable_subject_assignment
```

### **Check 3: Helper Function Exists**
```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'is_valid_subject_for_grade_section';
-- Should return: is_valid_subject_for_grade_section
```

### **Check 4: View Exists**
```sql
SELECT table_name FROM information_schema.tables
WHERE table_name = 'valid_timetable_entries'
AND table_type = 'VIEW';
-- Should return: valid_timetable_entries
```

---

## 🎯 AFTER MIGRATIONS - NEXT STEPS

Once migrations succeed, you're ready for:

1. **Backend Integration:**
   - Inject `GetValidSubjectsForGradeSelectionUseCase` in BLoC
   - Add BLoC events/states for loading valid subjects
   - Call validation before creating/publishing timetables

2. **Frontend Integration:**
   - Integrate use case into BLoC in Step 3
   - Redesign Step 4 with grade-specific subject dropdowns
   - Add validation error messages

3. **Reference:**
   - See `TIMETABLE_ACADEMIC_CONSISTENCY_IMPLEMENTATION.md` for detailed code examples

---

## ⚠️ TROUBLESHOOTING

### Error: "column grade_section_id already exists"
- **Cause:** Migration already partially ran
- **Solution:** Run `supabase db reset` to start fresh, or manually check if column exists

### Error: "ERROR: 42703: column grade_section_id referenced in foreign key constraint does not exist"
- **Cause:** First migration didn't complete properly
- **Solution:** Make sure to run migration #1 (20251111_refactor) BEFORE migration #2 (20251114_add_subject)

### Error: "Foreign key constraint violation"
- **Cause:** Orphaned entries in exam_timetable_entries table
- **Solution:** The fixed migration should handle this with the DELETE statement

### Error: "Function is_valid_subject_for_grade_section() already exists"
- **Cause:** Migration already ran successfully
- **Solution:** This is fine! You can re-run with `CREATE OR REPLACE` which we use

---

## 📝 SUMMARY CHECKLIST

- [ ] Read this document fully
- [ ] Backup your Supabase database (if production)
- [ ] Run `supabase db push` OR manually execute the two SQL files
- [ ] Verify all 4 checks above pass
- [ ] See next implementation steps in `TIMETABLE_ACADEMIC_CONSISTENCY_IMPLEMENTATION.md`

---

**Questions?** Check the implementation guide or let me know what errors you encounter! 🚀
