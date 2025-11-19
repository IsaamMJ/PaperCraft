-- Create students table
CREATE TABLE IF NOT EXISTS public.students (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  grade_section_id uuid NOT NULL REFERENCES public.grade_sections(id) ON DELETE CASCADE,
  roll_number text NOT NULL,
  full_name text NOT NULL,
  email text,
  phone text,
  academic_year text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  -- Constraints
  CONSTRAINT unique_student_per_grade_section UNIQUE(tenant_id, grade_section_id, roll_number, academic_year),
  CONSTRAINT student_roll_number_not_empty CHECK (roll_number != ''),
  CONSTRAINT student_full_name_not_empty CHECK (full_name != '')
);

-- Create indexes for students
CREATE INDEX IF NOT EXISTS idx_students_tenant_id
  ON public.students(tenant_id);
CREATE INDEX IF NOT EXISTS idx_students_grade_section_id
  ON public.students(grade_section_id);
CREATE INDEX IF NOT EXISTS idx_students_academic_year
  ON public.students(academic_year);
CREATE INDEX IF NOT EXISTS idx_students_is_active
  ON public.students(is_active);
CREATE INDEX IF NOT EXISTS idx_students_grade_section_academic
  ON public.students(grade_section_id, academic_year);

-- Enable RLS for students
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- RLS Policies for students
DROP POLICY IF EXISTS "students_select_policy" ON public.students;
DROP POLICY IF EXISTS "students_insert_policy" ON public.students;
DROP POLICY IF EXISTS "students_update_policy" ON public.students;
DROP POLICY IF EXISTS "students_delete_policy" ON public.students;

-- Select: Users can view students in their tenant
CREATE POLICY "students_select_policy" ON public.students
  FOR SELECT
  USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Insert: Only admins and office staff can add students
CREATE POLICY "students_insert_policy" ON public.students
  FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = ANY (ARRAY['admin', 'office_staff'])
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Update: Only admins and office staff can update students
CREATE POLICY "students_update_policy" ON public.students
  FOR UPDATE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = ANY (ARRAY['admin', 'office_staff'])
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = ANY (ARRAY['admin', 'office_staff'])
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Delete: Only admins can hard delete (soft delete via is_active)
CREATE POLICY "students_delete_policy" ON public.students
  FOR DELETE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

---
--- Create student_exam_marks table
---
CREATE TABLE IF NOT EXISTS public.student_exam_marks (
  id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  exam_timetable_entry_id uuid NOT NULL REFERENCES public.exam_timetable_entries(id) ON DELETE CASCADE,
  total_marks numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'present' CHECK (status = ANY (ARRAY['present', 'absent', 'not_appeared', 'medical_leave'])),
  remarks text,
  entered_by uuid NOT NULL REFERENCES public.profiles(id),
  is_draft boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),

  -- Constraints
  CONSTRAINT unique_student_exam_marks UNIQUE(student_id, exam_timetable_entry_id) WHERE is_active = true,
  CONSTRAINT valid_marks CHECK (total_marks >= 0)
);

-- Create indexes for student_exam_marks
CREATE INDEX IF NOT EXISTS idx_marks_tenant_id
  ON public.student_exam_marks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_marks_student_id
  ON public.student_exam_marks(student_id);
CREATE INDEX IF NOT EXISTS idx_marks_exam_timetable_entry_id
  ON public.student_exam_marks(exam_timetable_entry_id);
CREATE INDEX IF NOT EXISTS idx_marks_entered_by
  ON public.student_exam_marks(entered_by);
CREATE INDEX IF NOT EXISTS idx_marks_is_draft
  ON public.student_exam_marks(is_draft);
CREATE INDEX IF NOT EXISTS idx_marks_status
  ON public.student_exam_marks(status);
CREATE INDEX IF NOT EXISTS idx_marks_student_exam
  ON public.student_exam_marks(student_id, exam_timetable_entry_id);

-- Enable RLS for student_exam_marks
ALTER TABLE public.student_exam_marks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for student_exam_marks
DROP POLICY IF EXISTS "marks_select_policy" ON public.student_exam_marks;
DROP POLICY IF EXISTS "marks_insert_policy" ON public.student_exam_marks;
DROP POLICY IF EXISTS "marks_update_policy" ON public.student_exam_marks;
DROP POLICY IF EXISTS "marks_delete_policy" ON public.student_exam_marks;

-- Select: Users can view marks for their tenant
CREATE POLICY "marks_select_policy" ON public.student_exam_marks
  FOR SELECT
  USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Insert: Only teachers assigned to the exam can insert marks
CREATE POLICY "marks_insert_policy" ON public.student_exam_marks
  FOR INSERT
  WITH CHECK (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    AND
    (
      -- Teacher must be assigned to this grade/subject for this exam
      EXISTS (
        SELECT 1 FROM teacher_subjects ts
        JOIN exam_timetable_entries ete ON ts.grade_id = ete.grade_id AND ts.subject_id = ete.subject_id
        WHERE ts.teacher_id = auth.uid()
        AND ete.id = exam_timetable_entry_id
        AND ts.is_active = true
      )
      OR
      -- Admin or office staff can always insert
      (SELECT role FROM profiles WHERE id = auth.uid()) = ANY (ARRAY['admin', 'office_staff'])
    )
  );

-- Update: Only the teacher who entered the marks (or admin) can update, and only if is_draft = true
CREATE POLICY "marks_update_policy" ON public.student_exam_marks
  FOR UPDATE
  USING (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    AND
    (
      -- Original enterer can update only if still draft
      (entered_by = auth.uid() AND is_draft = true)
      OR
      -- Admin can always update
      (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    )
  )
  WITH CHECK (
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    AND
    (
      (entered_by = auth.uid() AND is_draft = true)
      OR
      (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    )
  );

-- Delete: Only admin can delete (soft delete via is_active)
CREATE POLICY "marks_delete_policy" ON public.student_exam_marks
  FOR DELETE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    AND
    tenant_id = (SELECT tenant_id FROM profiles WHERE id = auth.uid())
  );

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_student_exam_marks_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_student_exam_marks_timestamp ON public.student_exam_marks;
CREATE TRIGGER update_student_exam_marks_timestamp
  BEFORE UPDATE ON public.student_exam_marks
  FOR EACH ROW
  EXECUTE FUNCTION update_student_exam_marks_timestamp();

-- Create trigger to update students timestamp
CREATE OR REPLACE FUNCTION update_students_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_students_timestamp ON public.students;
CREATE TRIGGER update_students_timestamp
  BEFORE UPDATE ON public.students
  FOR EACH ROW
  EXECUTE FUNCTION update_students_timestamp();
