# Testing Guide - PDF Pagination Fix

## Quick Test with Your Problematic Paper

### 1. Run Your App
```bash
flutter run -d chrome
```

### 2. Test with grade5.txt Paper

Navigate to the Grade 5 English paper (the one you mentioned):
- **Title**: "Grade 5 English - 3 Feb 2026 (Section A)"
- **Exam Date**: 2026-02-03

### 3. Generate PDF Preview

Click the "PDF Preview" or "Generate PDF" button.

### 4. What to Check

**BEFORE (Old Behavior):**
- ❌ First page blank (only header visible)
- ❌ All content on second page
- ❌ Had to reduce font size manually (e.g., to 1.1x or 1.2x)
- ❌ Font became too small (hard to read)

**AFTER (Expected New Behavior):**
- ✅ First page contains actual question content
- ✅ Content starts immediately after header
- ✅ Font size 1.3x (15.6pt) works perfectly
- ✅ No manual adjustment needed
- ✅ Page breaks happen at logical section boundaries

### 5. Verify Page Content

**First Page Should Contain:**
- School name header
- Paper title: "Grade 5 English - 3 Feb 2026 (Section A)"
- Subject, Class, Date, Total Marks row
- Section I: "Choose the correct answer" (5 questions)
- Section II: "Match the following" (starts or fully visible)

**Second Page (if exists):**
- Continuation of remaining sections
- No big blank spaces at the top

### 6. Font Size Check

At default settings (1.3x multiplier):
- Question text should be ~15.6pt (readable, professional)
- Options should be ~13pt
- Section headers should be bold and clear

## Test with Other Papers

Test 5-10 other papers from your collection:

1. **Short papers** (1 page) - Should stay on 1 page
2. **Medium papers** (2 pages) - Should fill both pages evenly
3. **Long papers** (3+ pages) - Page breaks should be logical

### Papers to Prioritize:
- Papers with long "Fill in the blanks" questions
- Papers with "Match the following" sections
- Papers with multiple-choice questions with long options
- Papers with missing letters (two-column layout)

## If You Find Issues

Document:
1. Paper title and ID
2. What happened (screenshot if possible)
3. Font/spacing settings used
4. Expected vs actual behavior

Then we can fine-tune the height calculations further.

## Rollback if Needed

If the fix causes regressions:
```bash
git checkout master
```

This will revert to the old behavior while we refine the fix.

## Success Criteria

✅ **Pass**:
- No blank first pages
- Font size 1.3x works for all papers
- No manual adjustment needed
- Page breaks are logical

❌ **Fail**:
- Still getting blank first pages
- Content overflow/clipping
- Page breaks in middle of questions
- Need to adjust font below 1.2x

## Performance Check

The new pagination should be:
- Same speed or faster (no network calls)
- Memory usage unchanged
- PDF size similar to before

---

**Note**: PDF generation is stateless - you can regenerate any paper without affecting the database. Safe to test extensively!
