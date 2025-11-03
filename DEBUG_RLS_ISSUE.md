# Debug RLS INSERT Issue

## Possible Cause
Your JWT claims are correct in the database, but your app session might have:
1. An old JWT token cached
2. JWT token issued before the RLS policies were updated
3. Token not being refreshed after policy changes

## Test 1: Manually Test RLS Policy in Supabase

Go to Supabase SQL Editor and try to INSERT a test row:

```sql
-- Test if we can insert as your user
-- This will use the current session's JWT token

INSERT INTO public.grade_sections (
  id,
  tenant_id,
  grade_id,
  section_name,
  display_order,
  is_active
) VALUES (
  gen_random_uuid(),
  '5778b3cf-f63c-48d6-8a8c-5aa7f4b36edd',
  (SELECT id FROM public.grades LIMIT 1),
  'Test Section',
  1,
  true
);
```

**What happens?**
- If it works → RLS policy is fine, app needs JWT refresh
- If it fails → RLS policy still has issues

## Test 2: Force App to Refresh JWT Token

In your Flutter app:

1. **Completely close the app** (don't just minimize)
2. **Reopen the app**
3. **Log out**
4. **Log back in**
5. This forces a NEW JWT token to be issued by Supabase
6. Try the admin setup wizard again

The old cached JWT token from before the RLS policies were created won't work.

## Likely Solution

The problem is almost certainly a **stale JWT token in your app session**.

Supabase issues a JWT token when you log in. Even though your profile was updated to admin and the JWT claims were added to auth.users, your app still has the OLD token.

When you log in again (fresh app restart + log in), Supabase will issue a NEW JWT token that includes the admin role claim.

