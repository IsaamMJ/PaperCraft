-- Add is_onboarded column to track teacher onboarding completion
ALTER TABLE public.profiles 
ADD COLUMN is_onboarded boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_profiles_is_onboarded ON public.profiles(is_onboarded);
