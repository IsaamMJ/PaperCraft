# Admin Console Data Display Fix - Deployment Instructions

## 🎯 What This Fixes

✅ **Admin Dashboard** - Shows actual teacher names instead of "User"
✅ **Teacher Assignment** - Shows all teachers from the same tenant
✅ **Manage Users** - Shows all users from the same tenant

---

## 📋 Root Cause

Your Supabase **already has** a trigger (`on_auth_user_created`) that creates user profiles and assigns them to tenants correctly. However, it was **missing JWT claims**.

The RLS policies check:
```sql
tenant_id = (select auth.jwt()->>'tenant_id')::uuid
```

But the JWT didn't contain `tenant_id`, so queries were blocked and fell back to "User".

---

## 🔧 The Solution

The migration `20250126_add_jwt_claims_to_existing_trigger.sql` does THREE things:

### 1. Update the Existing Function
Modifies `handle_new_user_registration()` to:
- ✅ Keep existing domain-based tenant assignment logic
- ✅ **ADD** JWT claims update to `auth.users.raw_app_meta_data`
- ✅ Sets `tenant_id` and `role` in JWT claims

### 2. Create New Trigger for Updates
Creates `on_profile_updated_sync_jwt` trigger that:
- ✅ Fires when admin updates a profile
- ✅ Syncs `tenant_id` and `role` changes to JWT claims
- ✅ Keeps JWT in sync with profile data

### 3. Update Existing Users
Updates all existing auth.users records to:
- ✅ Populate JWT claims from their profile data
- ✅ Only updates users without existing JWT claims
- ✅ Safe and non-destructive

---

## ⚠️ Safety Information

**This migration is SAFE because:**

✅ Uses `CREATE OR REPLACE` (won't error if function exists)
✅ Uses `DROP ... IF EXISTS` (won't error if trigger doesn't exist)
✅ Has exception handling for errors
✅ Only adds/updates, never deletes
✅ Updates only modify metadata, not user/profile data
✅ No breaking changes to existing code

**Risk Level:** 🟢 LOW

---

## 📦 Deployment Steps

### Step 1: Backup Your Database (Optional but Recommended)

Go to Supabase Dashboard → Settings → Backups → Create a backup

### Step 2: Get the SQL

Copy this file:
```
supabase/migrations/20250126_add_jwt_claims_to_existing_trigger.sql
```

### Step 3: Run in Supabase

1. Open https://app.supabase.com
2. Select your project (hzjfibmuqzirokziewii)
3. Go to **SQL Editor**
4. Click **New Query**
5. Copy the entire contents of `20250126_add_jwt_claims_to_existing_trigger.sql`
6. Paste into the query editor
7. Click **Run** (or press Cmd+Enter)

### Step 4: Verify Success

After running, you should see no errors. The SQL will execute and return something like:

```
Query returned successfully with no results
```

### Step 5: Verify JWT Claims Were Set

Run this verification query in SQL Editor:

```sql
SELECT
  id,
  email,
  raw_app_meta_data->>'tenant_id' as tenant_id_in_jwt,
  raw_app_meta_data->>'role' as role_in_jwt
FROM auth.users
LIMIT 5;
```

**Expected Result:**
- `tenant_id_in_jwt` should have UUID values (not NULL)
- `role_in_jwt` should have 'teacher', 'admin', or 'user' values

### Step 6: Test in Your App

After deploying, test these scenarios:

1. **Admin Dashboard**
   - Go to admin dashboard
   - Check paper cards
   - Should show actual teacher names instead of "User"

2. **Teacher Assignment**
   - Go to admin settings → Teacher Assignment
   - Should show list of teachers from your tenant

3. **Manage Users**
   - Go to admin settings → Manage Users
   - Should show list of users from your tenant

---

## 🔍 If Something Goes Wrong

### Issue: Query errors when running migration

**Solution:** The function might have different syntax in your version
- Copy the error message
- Run the safer version (drop first, then create)

### Issue: No errors but data still not showing

**Solution:** Existing users need to logout and login

- The JWT claims update happens on LOGIN
- Ask users to logout and login again
- Or wait ~1 hour for JWT to refresh

### Issue: Rollback (if needed)

You can manually drop the trigger:

```sql
DROP TRIGGER IF EXISTS on_profile_updated_sync_jwt ON profiles;
```

This won't break anything - it just means profile updates won't sync to JWT.

---

## 📊 What Changes in Your Database

### New Trigger
```
Name: on_profile_updated_sync_jwt
Table: profiles
Event: AFTER UPDATE
Function: update_jwt_claims_on_profile_update()
```

### Updated Function
```
Name: handle_new_user_registration
Changes: Added JWT claims update
Effect: New users get JWT claims on signup
```

### Updated Records
```
auth.users table:
- raw_app_meta_data field now includes:
  - "tenant_id": "uuid-value"
  - "role": "teacher|admin|user"
```

---

## 🚀 Testing the Fix

### Before Running Migration

```sql
-- Run this to see current state
SELECT email, raw_app_meta_data->>'tenant_id' as has_tenant_id
FROM auth.users
WHERE raw_app_meta_data->>'tenant_id' IS NULL
LIMIT 5;
```

Expected: Shows users WITHOUT tenant_id in JWT

### After Running Migration

```sql
-- Run this again to verify fix
SELECT email, raw_app_meta_data->>'tenant_id' as has_tenant_id
FROM auth.users
LIMIT 5;
```

Expected: All users now have tenant_id in JWT

---

## 📞 Support

If you encounter issues:

1. Check the migration file for any errors
2. Run the verification query above
3. Check browser console for error messages
4. Users may need to logout/login for changes to take effect

---

## ✅ Checklist

Before running:
- [ ] Backup created (optional)
- [ ] Migration file located
- [ ] Supabase console open

After running:
- [ ] No SQL errors
- [ ] Verification query shows tenant_id in JWT
- [ ] Logout/login users (or wait 1 hour)
- [ ] Test admin dashboard shows names
- [ ] Test teacher assignment shows teachers
- [ ] Test manage users shows users

---

## Files Involved

📄 `supabase/migrations/20250126_add_jwt_claims_to_existing_trigger.sql` - **The migration to run**

📄 `ADMIN_DATA_DISPLAY_FIX.md` - Root cause analysis

📄 `SUPABASE_SAFETY_ANALYSIS.md` - Safety assessment

📄 `SUPABASE_GET_ALL_TRIGGERS_AND_FUNCTIONS.md` - Database structure reference

📄 `DEPLOYMENT_INSTRUCTIONS.md` - **This file**

---

## Questions?

- **What if I don't run this?** - Admin console will continue showing "User" instead of names
- **Can I run this on production?** - Yes, it's safe and non-destructive
- **Will existing data be lost?** - No, only metadata is updated
- **Do users need to do anything?** - Logout/login after deployment for JWT refresh

---

**Ready to deploy?** Go to Step 2 above! 🚀
