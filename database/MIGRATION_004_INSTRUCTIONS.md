# Migration 004: Dynamic Paper Sections

## Overview
This migration replaces the rigid `exam_types` system with dynamic, flexible section building. Teachers can now create paper structures on-the-fly without admin intervention.

## What Changes

### Tables Created
- **`teacher_patterns`** - Stores auto-saved section patterns for teacher reuse

### Tables Modified
- **`question_papers`** - Adds `paper_sections` JSONB column, removes `exam_type_id` FK

### Tables Dropped
- **`exam_types`** - No longer needed (sections stored directly in papers)

## Migration Steps

### Option 1: Run via Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `004_dynamic_paper_sections.sql`
4. Click "Run"
5. Verify success (see verification queries at end of file)

### Option 2: Run via Supabase CLI

```bash
# From project root
supabase db push

# Or apply specific migration
psql -h your-db-host -U postgres -d postgres -f database/migrations/004_dynamic_paper_sections.sql
```

### Option 3: Run Manually (if no Supabase CLI)

```sql
-- Connect to your database and run:
\i database/migrations/004_dynamic_paper_sections.sql
```

## Data Migration

### Existing Papers
All existing `question_papers` will have their `exam_type.sections` copied into the new `paper_sections` column. The migration script handles this automatically:

```sql
UPDATE question_papers qp
SET paper_sections = et.sections
FROM exam_types et
WHERE qp.exam_type_id = et.id;
```

### Existing Exam Types
The `exam_types` table will be dropped. If you want to preserve exam types as teacher patterns, export them first:

```sql
-- OPTIONAL: Export exam types as teacher patterns before migration
INSERT INTO teacher_patterns (tenant_id, teacher_id, subject_id, name, sections, total_questions, total_marks)
SELECT
  et.tenant_id,
  (SELECT id FROM users WHERE tenant_id = et.tenant_id AND role = 'admin' LIMIT 1),
  et.subject_id,
  et.name,
  et.sections,
  (SELECT SUM((s->>'questions')::int) FROM jsonb_array_elements(et.sections) s),
  (SELECT SUM((s->>'questions')::int * (s->>'marks_per_question')::int) FROM jsonb_array_elements(et.sections) s)
FROM exam_types et;
```

## Verification

After running the migration, verify success:

### 1. Check teacher_patterns table exists
```sql
SELECT COUNT(*) FROM teacher_patterns;
-- Should return 0 (no patterns yet)
```

### 2. Check question_papers has paper_sections
```sql
SELECT id, paper_sections
FROM question_papers
LIMIT 1;
-- Should show sections JSONB data
```

### 3. Check exam_types is dropped
```sql
SELECT * FROM exam_types;
-- Should return: ERROR: relation "exam_types" does not exist
```

### 4. Check RLS policies
```sql
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename = 'teacher_patterns';
-- Should show "Teachers manage own patterns" policy
```

## Rollback

⚠️ **WARNING**: Rollback is complex because the `exam_types` table is dropped.

### Rollback Steps (only if needed)

1. **Restore exam_types table from backup**
2. **Re-add exam_type_id column:**
   ```sql
   ALTER TABLE question_papers
     ADD COLUMN exam_type_id UUID REFERENCES exam_types(id);
   ```
3. **Map papers back to exam types** (manual, complex)
4. **Drop new columns:**
   ```sql
   ALTER TABLE question_papers DROP COLUMN paper_sections;
   DROP TABLE teacher_patterns CASCADE;
   ```

## Testing Checklist

After migration, test these scenarios:

- [ ] Old papers still display correctly
- [ ] Old papers can be viewed/printed (PDF generation works)
- [ ] New papers can be created without selecting exam type
- [ ] Sections can be added/removed dynamically
- [ ] Patterns auto-save after paper creation
- [ ] Patterns appear in dropdown on next creation
- [ ] RLS works (teachers only see own patterns)

## Troubleshooting

### Error: "relation exam_types does not exist"
**Solution**: This is expected after migration. Update your code to not reference `exam_types`.

### Error: "column paper_sections is null"
**Solution**: Run the UPDATE query to migrate data from exam_types to paper_sections.

### Error: "permission denied for table teacher_patterns"
**Solution**: Check RLS policies are created correctly. Teachers must be authenticated.

## Support

If you encounter issues, check:
1. Supabase logs for detailed error messages
2. Database connection is stable
3. You have sufficient permissions (need superuser/owner role)
4. All prerequisite migrations (001-003) ran successfully

## Next Steps

After successful migration:
1. Update Flutter app code to use dynamic sections
2. Remove exam type selection UI
3. Add section builder UI
4. Test thoroughly with real papers
5. Deploy updated app to users
