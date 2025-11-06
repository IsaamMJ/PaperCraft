-- Add missing foreign key constraints for teacher_subjects table
-- These are required for Supabase PostgREST to detect join relationships

-- Add FK constraint from teacher_subjects to profiles (via teacher_id)
-- Enables joining: teacher_subjects -> profiles to get teacher name and email
ALTER TABLE public.teacher_subjects
  ADD CONSTRAINT teacher_subjects_teacher_id_fkey
  FOREIGN KEY (teacher_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Add FK constraint from teacher_subjects to subjects
-- This allows PostgREST to join teacher_subjects with subjects table
-- Since subjects is a tenant-scoped mapping table that references subject_catalog,
-- we need this FK to enable nested joins: teacher_subjects -> subjects -> subject_catalog
ALTER TABLE public.teacher_subjects
  ADD CONSTRAINT teacher_subjects_subject_id_fkey
  FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE;

-- Add FK constraint from subjects to subject_catalog
-- This enables nested join: subjects -> subject_catalog to get the actual subject name
ALTER TABLE public.subjects
  ADD CONSTRAINT subjects_catalog_subject_id_fkey
  FOREIGN KEY (catalog_subject_id) REFERENCES public.subject_catalog(id) ON DELETE CASCADE;

-- These constraints enable Supabase's auto-join detection for nested queries like:
-- .select('id, ..., profiles(full_name, email), subjects(subject_catalog(subject_name))')
-- The complete join path is: teacher_subjects -> subjects -> subject_catalog
-- where subject_name comes from the nested subject_catalog table
