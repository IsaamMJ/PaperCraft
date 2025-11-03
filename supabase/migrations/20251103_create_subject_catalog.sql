-- Drop existing table if it exists (to clean up any partial creation)
DROP TABLE IF EXISTS public.subject_catalog CASCADE;

-- Create subject catalog table for admin setup wizard
-- This table defines available subjects for each grade level
CREATE TABLE public.subject_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_name TEXT NOT NULL,
  min_grade INTEGER NOT NULL,
  max_grade INTEGER NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT subject_catalog_valid_grades CHECK (min_grade >= 1 AND min_grade <= 12),
  CONSTRAINT subject_catalog_grade_order CHECK (max_grade >= min_grade AND max_grade <= 12),
  UNIQUE(subject_name, min_grade, max_grade)
);

-- Create indexes for common queries
CREATE INDEX idx_subject_catalog_grades ON public.subject_catalog(min_grade, max_grade);
CREATE INDEX idx_subject_catalog_active ON public.subject_catalog(is_active);

-- Enable RLS
ALTER TABLE public.subject_catalog ENABLE ROW LEVEL SECURITY;

-- Create policy: Allow reading subject catalog to all authenticated users
CREATE POLICY "Allow reading subject catalog"
  ON public.subject_catalog
  FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Seed common subjects with their typical grade ranges
INSERT INTO public.subject_catalog (subject_name, min_grade, max_grade, description, is_active)
VALUES
  ('Mathematics', 1, 12, 'Core mathematics subject', true),
  ('English', 1, 12, 'English language and literature', true),
  ('Science', 1, 12, 'General science', true),
  ('Physics', 9, 12, 'Physics course', true),
  ('Chemistry', 9, 12, 'Chemistry course', true),
  ('Biology', 9, 12, 'Biology course', true),
  ('History', 6, 12, 'History and social studies', true),
  ('Geography', 6, 12, 'Geography and environmental studies', true),
  ('Computer Science', 6, 12, 'Computer science and IT', true),
  ('Art', 1, 12, 'Visual arts', true),
  ('Music', 1, 12, 'Music education', true),
  ('Physical Education', 1, 12, 'Physical education and sports', true),
  ('Urdu', 1, 12, 'Urdu language', true),
  ('Islamiat', 1, 12, 'Islamic studies', true),
  ('Pakistan Studies', 6, 12, 'Pakistan studies', true),
  ('Economics', 9, 12, 'Economics course', true),
  ('Statistics', 9, 12, 'Statistics and probability', true),
  ('Sindhi', 1, 12, 'Sindhi language', true),
  ('Pashto', 1, 12, 'Pashto language', true),
  ('Punjabi', 1, 12, 'Punjabi language', true)
ON CONFLICT DO NOTHING;

-- Add table comments
COMMENT ON TABLE public.subject_catalog IS 'Catalog of available subjects with grade ranges for use in school setup wizard';
COMMENT ON COLUMN public.subject_catalog.id IS 'Unique identifier';
COMMENT ON COLUMN public.subject_catalog.subject_name IS 'Name of the subject';
COMMENT ON COLUMN public.subject_catalog.min_grade IS 'Minimum grade level for this subject (1-12)';
COMMENT ON COLUMN public.subject_catalog.max_grade IS 'Maximum grade level for this subject (1-12)';
COMMENT ON COLUMN public.subject_catalog.description IS 'Description of the subject';
COMMENT ON COLUMN public.subject_catalog.is_active IS 'Whether this subject is available for selection';
