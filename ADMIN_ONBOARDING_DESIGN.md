# Admin & Teacher Onboarding Design - Simplified

## Overview

Simple user initialization flow for PaperCraft:
- **School users (@school.edu)** → Auto-assigned to school tenant by existing DB logic
- **First user from domain** → Auto-admin role
- **Subsequent users from domain** → Auto-teacher role
- **Personal email users (@gmail.com)** → Solo teacher, separate tenant, admin by default

**Key:** We only document the **Onboarding Flows** (UI/UX). Role assignment in DB is already perfect.

---

## Core Principle

**Schools = Domain Based | Teachers = Personal Email Only**

- Schools MUST use school domain (example.edu.in)
- First user from domain becomes ADMIN automatically
- Subsequent users from domain become TEACHER automatically
- Personal email users are SOLO TEACHERS
- No invite system needed
- No complex role management
- add infor like if you want to set up help contact isaam.mj@gmail.com
---

## User Types

### **School Admin**
- First user from @school.edu domain
- Auto-assigned ADMIN role (by DB logic)
- Purpose: Setup school (grades, sections, subjects)
- Onboarding: 4-step wizard

### **School Teacher**
- Any subsequent user from @school.edu domain
- Auto-assigned TEACHER role (by DB logic)
- Purpose: Create questions for assigned grades/sections/subjects
- Onboarding: 3-step wizard

### **Solo Teacher**
- Any user with personal email (@gmail.com, @outlook.com, etc.)
- Auto-assigned ADMIN role (solo mode only)
- Purpose: Create questions for self
- Onboarding: 2-step wizard
- Note: Cannot manage school, cannot invite others

---

## Signup Flow (Entry Point)

```
User enters email on signup page
│
├─ EXISTING DB LOGIC checks domain
│
├─ CASE 1: School domain (stxavier.edu.in)
│  ├─ Check tenant exists? (pre-created by admin)
│  │  └─ YES ✓
│  ├─ Check first user from this domain?
│  │  ├─ YES → Auto-assign ADMIN role
│  │  │         → Go to ADMIN ONBOARDING
│  │  └─ NO → Auto-assign TEACHER role
│  │           → Go to TEACHER ONBOARDING
│
├─ CASE 2: Personal domain (gmail.com, outlook.com, etc.)
│  ├─ Auto-create personal tenant
│  ├─ Auto-assign ADMIN role (solo)
│  └─ Go to SOLO TEACHER ONBOARDING
│
└─ User password setup, then onboarding
```

---

## Onboarding Flows

### **FLOW 1: School Admin Onboarding (4 Steps)**

**When:** First user from school domain logs in

keep it simple dont give much poptions and confuse the admin 
**STEP 1: Grades**
```
Title: "Select Grades Your School Teaches"

UI:
├─ Checkboxes for: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
├─ Multi-select allowed
├─ Example: Admin selects 5, 6, 7, 8, 9, 10
├─ "Quick Add" button: Add common ranges (1-5, 6-10, etc.)
└─ [Next]
```

**STEP 2: Sections (Per Grade)**
```
Title: "Add Sections for Each Grade"

UI (for each selected grade):
├─ Grade 5:  [A] [B] [C] (add more button)
├─ Grade 6:  [A] [B] [C] [D]
├─ Grade 7:  [A] [B]
├─ etc.

Admin can:
├─ Add sections individually
├─ "Duplicate from above" button (copy Grade 5 sections to Grade 6)
├─ "Quick Set" button: All grades get A, B, C
└─ [Next]
```

**STEP 3: Add Subjects Per Grade**
```
Title: "Which Subjects Are Taught in Each Grade?"

UI (for each selected grade):
├─ Grade 5:
│  ├─ Text input: [Math] [Add]
│  ├─ Added: Math, Science, English, History (can delete)
│  └─ Suggested below: Math, Science, English, History, Geography, etc.
│
├─ Grade 6:
│  ├─ Text input: [Math] [Add]
│  ├─ Added: Math, Science, English, History, Geography (can delete)
│  └─ Suggested below: ...
│
├─ Grade 7:
│  ├─ Text input: [Math] [Add]
│  ├─ Added: Math, Physics, Chemistry, English, Biology (can delete)
│  └─ Suggested below: ...
│
└─ Continue for all selected grades
└─ [Next]

Example:
Grade 5-6: Basic subjects (Math, Science, English, History)
Grade 9-10: Stream subjects (Math, Physics, Chemistry, Biology)
```

**STEP 4: Review & Complete**
```
Title: "Review Your Setup"

UI:
├─ Summary:
│  ├─ Grades: 5, 6, 7, 8, 9, 10 (6 grades)
│  ├─ Sections: Total 15 sections
│  │  └─ Grade 5: A, B, C
│  │  └─ Grade 6: A, B, C, D
│  │  └─ (etc.)
│  └─ Subjects per Grade:
│     └─ Grade 5: Math, Science, English, History
│     └─ Grade 6: Math, Science, English, History, Geography
│     └─ Grade 9: Math, Physics, Chemistry, Biology, English
│     └─ Grade 10: Math, Physics, Chemistry, Biology, English
│     └─ (etc.)
│
├─ Buttons:
│  ├─ [Back] (edit any step)
│  └─ [Complete Setup!]
│
└─ After click:
   ├─ Setup saved
   └─ Redirect to Admin Dashboard
```

---

### **FLOW 2: School Teacher Onboarding (3 Steps)**

**When:** Subsequent user from school domain logs in

**STEP 1: Select Grades You Teach**
```
Title: "Which Grades Do You Teach?"

UI:
├─ Checkboxes for all school grades: 5, 6, 7, 8, 9, 10
├─ Multi-select allowed
├─ Example: Teacher selects 5, 6, 7
└─ [Next]
```

**STEP 2: Select Sections (Per Grade)**
```
Title: "Which Sections Do You Teach?"

UI (for each selected grade):
├─ Grade 5:
│  ├─ Checkboxes: [A] [B] [C]
│  ├─ Teacher selects: A, B
│
├─ Grade 6:
│  ├─ Checkboxes: [A] [B] [C] [D]
│  ├─ Teacher selects: A, C
│
└─ Grade 7:
   ├─ Checkboxes: [A] [B]
   └─ Teacher selects: B

[Next]
```

**STEP 3: Select Subjects Per Grade**
```
Title: "Which Subjects Do You Teach in Each Grade?"

UI (for each selected grade):
├─ Grade 5:
│  ├─ Available subjects: Math, Science, English, History
│  ├─ Checkboxes: [✓Math] [✓Science] [English] [History]
│  ├─ Teacher selects: Math, Science
│
├─ Grade 6:
│  ├─ Available subjects: Math, Science, English, History, Geography
│  ├─ Checkboxes: [✓Math] [Science] [English] [History] [Geography]
│  ├─ Teacher selects: Math
│
└─ Grade 7:
   ├─ Available subjects: Math, Physics, Chemistry, English, Biology
   ├─ Checkboxes: [Math] [✓Physics] [Chemistry] [English] [Biology]
   └─ Teacher selects: Physics

[Complete]

Result Assignment:
├─ Grade 5-A: Math, Science
├─ Grade 5-B: Math, Science
├─ Grade 6-A: Math
├─ Grade 6-C: Math
├─ Grade 7-B: Physics
└─ (Only subjects available for each grade)
```

**After Completion:**
```
Redirect to Teacher Dashboard
└─ Teacher can now create questions
```

---

### **FLOW 3: Solo Teacher Onboarding (2 Steps)**

**When:** User with personal email (@gmail.com, @outlook.com) signs up

**STEP 1: Select Grades**
```
Title: "Which Grades Do You Teach?"

UI:
├─ Checkboxes for standard grades: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
├─ Multi-select allowed
├─ Example: Teacher selects 9, 10, 11
└─ [Next]

Note: No sections for solo teachers (not applicable)
```

**STEP 2: Select Subjects**
```
Title: "Which Subjects Do You Teach?"

UI:
├─ Checkboxes for standard subjects:
│  ├─ Math, Science, Physics, Chemistry, Biology
│  ├─ English, History, Geography, Economics
│  ├─ Art, Physical Education, Computer Science, etc.
├─ Multi-select allowed
├─ Example: Teacher selects Math, Physics
└─ [Complete]

Result Assignment:
├─ Grade 9: Math, Physics
├─ Grade 10: Math, Physics
├─ Grade 11: Math, Physics
└─ (All combinations of selected grades × subjects)
```

**After Completion:**
```
Redirect to Solo Dashboard
└─ Teacher can now create questions
└─ Cannot manage school, invite others, or see team features
```

---

## School Registration (Simple Info)

**For schools wanting to setup PaperCraft:**

Display on signup page or landing page:

```
┌─────────────────────────────────────────┐
│ Want to set up PaperCraft for your      │
│ school?                                  │
│                                          │
│ Ping us: isaam.mj@gmail.com             │
│                                          │
│ We'll get back to you with setup        │
│ instructions and domain registration.   │
└─────────────────────────────────────────┘
```

**What happens after contact:**
1. User emails isaam.mj@gmail.com with school details
2. Admin approves and creates tenant for school domain
3. Admin replies with setup link
4. First user from school domain signs up
5. Automatic admin onboarding starts

---

## Database - No Changes Needed

**Existing logic already handles:**
✅ Domain detection (school vs personal)
✅ First user = ADMIN, subsequent = TEACHER
✅ Tenant auto-assignment
✅ Role auto-assignment

**We're only adding onboarding UI flows on top of existing DB logic.**

---

## Summary Table

| User | Domain | First? | Role | Onboarding | Steps | Time |
|------|--------|--------|------|-----------|-------|------|
| School Admin | @school.edu | YES | Auto-Admin | Admin Wizard | 4 | ~10 min |
| School Teacher | @school.edu | NO | Auto-Teacher | Teacher Wizard | 3 | ~5 min |
| Solo Teacher | @gmail.com | - | Auto-Admin (solo) | Solo Wizard | 2 | ~3 min |

---

## Key Features

✅ **Domain-based auto-assignment** - Already working in DB
✅ **Role-based auto-assignment** - Already working in DB
✅ **Simple admin setup** - 4 steps: Grades → Sections → Subjects → Review
✅ **Simple teacher setup** - 3 steps: Grades → Sections → Subjects
✅ **Simple solo setup** - 2 steps: Grades → Subjects
✅ **No sections for solo teachers** - Cleaner for individuals
✅ **Quick add buttons** - Duplicate, template suggestions
✅ **School registration** - Simple email contact, no form

---

## Pages Needed

### New Pages to Build

1. **Admin Setup Wizard**
   - File: `lib/features/admin/presentation/pages/admin_setup_wizard.dart`
   - 4-step wizard as detailed above

2. **Teacher Onboarding (School)**
   - File: `lib/features/onboarding/presentation/pages/teacher_onboarding_page.dart`
   - 3-step wizard as detailed above

3. **Solo Teacher Onboarding**
   - File: `lib/features/onboarding/presentation/pages/solo_teacher_onboarding_page.dart`
   - 2-step wizard as detailed above

### Modified Pages

1. **Signup Page**
   - Add: School registration info banner
   - Add: Domain detection logic (already exists)

2. **Admin/Teacher Dashboard**
   - Redirect to appropriate onboarding if not completed

---

## Technical Integration

**Onboarding triggers:**
```
User signs up
  └─ Domain detected by EXISTING logic
  └─ Role assigned by EXISTING logic
  └─ onboarded = false (flag in DB)
  └─ Navigate to appropriate onboarding page

After onboarding completes:
  └─ Save grades, sections, subjects to DB
  └─ Set onboarded = true
  └─ Redirect to dashboard
```

---

## Edge Cases Handled

✅ User closes onboarding midway → Can restart
✅ User tries to access dashboard without onboarding → Redirect to onboarding
✅ Admin creates 0 subjects → Show warning "Please add at least 1 subject"
✅ Teacher selects grades but no sections → Show error "Select at least 1 section"
✅ Personal email duplicate signup → Normal auth (create new account)

---

## Questions?

1. Should admin be able to EDIT grades/sections/subjects after setup?
2. Should teacher be able to UPDATE their assigned grades/sections/subjects later?
3. Should onboarding be skippable or mandatory?
4. Any other UI preferences for the steps?

