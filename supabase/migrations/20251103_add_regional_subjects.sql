-- Add regional and core subjects if not already present
INSERT INTO public.subject_catalog (subject_name, min_grade, max_grade, description, is_active)
VALUES
  ('Tamil', 1, 12, 'Tamil language and literature', true),
  ('Maths', 1, 12, 'Mathematics - Alternative name', true),
  ('EVS', 1, 5, 'Environmental Studies (Primary grades)', true),
  ('Social', 1, 12, 'Social Studies and Social Science', true)
ON CONFLICT (subject_name, min_grade, max_grade) DO NOTHING;

-- Verify insertion
SELECT subject_name, min_grade, max_grade FROM public.subject_catalog 
WHERE subject_name IN ('Tamil', 'English', 'Maths', 'Science', 'EVS', 'Social')
ORDER BY subject_name;
