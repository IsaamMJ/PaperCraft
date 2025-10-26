# Supabase Safety Analysis - Results

## ✅ GOOD NEWS: Safe to Deploy!

Your Supabase database **ALREADY HAS** the critical trigger we need! This is actually great news.

---

## What I Found

### 1. **Existing Trigger (Already There) ✅**

```
Trigger Name: on_auth_user_created
Schema: auth
Table: users
Event: INSERT
Function: handle_new_user_registration()
```

**This trigger ALREADY exists and fires on new user creation!**

---

### 2. **Existing Function (Already There) ✅**

```
Function: handle_new_user_registration()
Schema: public
Type: FUNCTION (TRIGGER)
```

**The function that creates profiles is already implemented!**

Let me show you what it does:

```sql
DECLARE
  user_domain TEXT;
  default_role TEXT;
  assigned_tenant_id UUID;
  tenant_name TEXT;
BEGIN
  -- Check email domain
  IF user_domain = 'pearlmatricschool.com' THEN
    default_role := 'teacher';
  ELSIF user_domain = 'gmail.com' THEN
    default_role := 'admin';
  ELSE
    default_role := 'user';
  END IF;

  -- Assign tenant based on domain
  IF user_domain = 'pearlmatricschool.com' THEN
    -- Assign to existing tenant by domain
    SELECT id INTO assigned_tenant_id
    FROM public.tenants
    WHERE domain = user_domain AND is_active = true
    LIMIT 1;

  ELSIF user_domain = 'gmail.com' THEN
    -- Create new tenant for Gmail users (admins)
    INSERT INTO public.tenants (name, domain, is_active)
    VALUES (tenant_name, NULL, true)
    RETURNING id INTO assigned_tenant_id;
  END IF;

  -- Create profile with tenant_id
  INSERT INTO public.profiles (
    id, email, full_name, tenant_id, role, is_active, last_login_at
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    assigned_tenant_id,  -- ← Sets tenant_id here!
    default_role,
    true,
    NOW()
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Profile creation failed for user %: %', NEW.id, SQLERRM;
    RAISE;
END;
```

---

## What This Means

### ✅ **The Good Part:**
1. **User profiles ARE being created** when new users sign up ✓
2. **tenant_id IS being set** in the profiles table ✓
3. **Tenants ARE being created** for new admin users ✓
4. **Error handling is in place** ✓

### ⚠️ **The Missing Part:**
The existing function creates profiles with `tenant_id`, but it does NOT set JWT claims in `auth.users.raw_app_meta_data`.

This means:
- ❌ `auth.jwt()->>'tenant_id'` is **NOT** populated
- ❌ RLS policies checking JWT claims will **FAIL**

---

## Why Your Issues Are Happening

The profile **does exist** (because the trigger creates it), but:

1. The JWT token doesn't have `tenant_id` claim
2. RLS policies like `tenant_id = (select auth.jwt()->>'tenant_id')::uuid` **FAIL**
3. Queries are blocked by RLS
4. Data lookups fail silently → fallback to 'User'

---

## What You Need to Do

**DO NOT run** my `20250126_create_user_profile_trigger.sql` - it will conflict!

**INSTEAD, you need to modify** the existing `handle_new_user_registration()` function to:
1. Keep all the existing logic (domain checking, tenant creation, etc.)
2. **ADD** the JWT claims update to `auth.users.raw_app_meta_data`

---

## The Real Solution

You need to **UPDATE the existing function** to include JWT claims. Here's what needs to be added:

```sql
-- After the profile is inserted, update JWT claims
UPDATE auth.users
SET raw_app_meta_data =
  COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object(
    'tenant_id', assigned_tenant_id::text,
    'role', default_role
  )
WHERE id = NEW.id;
```

This should be added to the `handle_new_user_registration()` function right after the profile insert.

---

## Updated Migration Strategy

Instead of creating new triggers, I need to:

1. **Modify existing function** `handle_new_user_registration()` to update JWT claims
2. **Create a trigger on profiles UPDATE** to sync JWT claims when profile is updated (for admin updates)
3. **Update all existing users** with JWT claims from their profiles

This way:
- ✅ We don't conflict with existing setup
- ✅ We fix the JWT claims issue
- ✅ We leverage the existing domain-based tenant assignment logic

---

## Status Summary

| Item | Status | Notes |
|------|--------|-------|
| User profile creation | ✅ Working | Trigger exists and fires |
| Profile has tenant_id | ✅ Working | Function sets it correctly |
| Tenant creation | ✅ Working | Auto-creates for Gmail users |
| JWT claims (tenant_id) | ❌ Missing | This is what's breaking RLS |
| JWT claims (role) | ❌ Missing | This is also needed for RLS |
| RLS policies | ✅ Correct | They check JWT but claims don't exist |

---

## Next Step

I need to create a **MODIFIED** migration that:
- ✅ Updates the existing function (not replaces it)
- ✅ Adds JWT claim updates
- ✅ Creates a trigger on profile updates to keep JWT in sync
- ✅ Updates all existing users

Should I create this modified, safer migration?
