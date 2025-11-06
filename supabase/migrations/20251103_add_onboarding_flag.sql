-- Add onboarding completion flag to profiles table
-- This tracks whether a teacher has completed their personal onboarding

ALTER TABLE profiles ADD COLUMN has_completed_onboarding BOOLEAN DEFAULT FALSE;

-- Add comment for clarity
COMMENT ON COLUMN profiles.has_completed_onboarding IS
'Tracks whether this user has completed their personal onboarding setup.
True for admins (they complete tenant setup instead),
False for new teachers until they complete teacher onboarding.';
